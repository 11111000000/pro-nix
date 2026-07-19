#!/usr/bin/env bash
# simple-helper-switch — быстрая активация перед switch
#
# Использует nixpkgs defaults напрямую (без кастомных модулей).
# Предлагает использовать boot для избежания race conditions при switch.
#
# Политика submodules (по умолчанию, без флагов):
#   - submodules инициализированы?  → ничего не делаем, используем как есть.
#   - submodules НЕ инициализированы? → `git submodule update --init --recursive`.
#   - submodules отсутствуют в .gitmodules? → ничего не делаем (Nix нечего собирать
#     из submodules/, emacs-recipes упадут, но это и так видно сразу).
# Явное обновление — `just switch ... update-submodules` или `just sync-submodules`.
# Полная документация — scripts/sync-submodules.sh + AGENTS.md §6d.

HOST_ARG="${1:-}"
HOST_ARG="${HOST_ARG#HOST=}"
# FLAGS_ARG (опционально): проброс флагов из just switch (positional arg).
# Поддерживаемые: update-submodules, sync (включают обновление с remote).
FLAGS_ARG="${2:-}"
# Use git+file:// with submodules=1 so nix captures submodules into the store
# source. Local path: URLs do not include submodules, which breaks the emacs
# recipes that read `../../submodules/<name>` as their source.
FLAKE_REF="git+file://$PWD?submodules=1"

if [ -z "$HOST_ARG" ]; then
  if [ -r /etc/hostname ]; then
    HOST_ARG=$(</etc/hostname)
  elif command -v hostname >/dev/null 2>&1; then
    HOST_ARG=$(hostname -s 2>/dev/null || hostname 2>/dev/null || true)
  fi
fi

if [ -z "$HOST_ARG" ]; then
  echo "No hostname detected." >&2
  exit 1
fi

if [ ! -f "./hosts/$HOST_ARG/configuration.nix" ]; then
  echo "No config: ./hosts/$HOST_ARG/configuration.nix" >&2
  echo "Available hosts:" >&2
  for h in ./hosts/*/configuration.nix; do
    [ -f "$h" ] || continue
    echo "  just switch $(basename "$(dirname "$h")")" >&2
  done
  exit 1
fi

echo "[simple-helper] Checking configuration for host: $HOST_ARG"

# Решаем, что делать с submodules перед сборкой:
#   update  — передан update-submodules / sync (или `just sync-submodules`)
#   skip    — PRO_NIX_NO_SUBMODULE_UPDATE=1 (escape hatch)
#   init    — submodules не инициализированы → `git submodule update --init --recursive`
#   skip    — submodules уже инициализированы → используем как есть, ничего не делаем
#   skip    — submodules отсутствуют в .gitmodules → Nix нечего собирать из submodules/
#
# Проверяем substring (без требования `--` префикса), чтобы just
# мог передать флаг и как `--update-submodules`, и как `update-submodules`.
SUBMODULE_MODE="auto"
case "$FLAGS_ARG" in
  *update-submodules*|*sync*)
    SUBMODULE_MODE="update"
    ;;
esac
[ -n "${PRO_NIX_NO_SUBMODULE_UPDATE:-}" ] && SUBMODULE_MODE="skip"

if [ "$SUBMODULE_MODE" = "auto" ]; then
  # `git submodule status` выводит строки вида " <sha> path" для инициализированных
  # и "-<sha> path" для неинициализированных (нужен --init). Если grep -q '^-'
  # совпал — хотя бы один submodule не инициализирован.
  if git submodule status 2>/dev/null | grep -q '^-'; then
    SUBMODULE_MODE="init"
  else
    SUBMODULE_MODE="skip"
  fi
fi

echo ""
case "$SUBMODULE_MODE" in
  update)
    echo "[simple-helper] --update-submodules: refreshing remote submodules before switch..."
    bash "$(dirname "$0")/sync-submodules.sh"
    ;;
  init)
    echo "[simple-helper] Submodules not initialized. Running: git submodule update --init --recursive"
    if ! git submodule update --init --recursive; then
      echo "[simple-helper] WARNING: init failed, continuing with whatever is available" >&2
    fi
    ;;
  skip)
    echo "[simple-helper] Using existing submodules (no update)."
    echo "[simple-helper] Pass update-submodules / sync or run 'just sync-submodules' to refresh from remote."
    ;;
esac

# Запуск switch с сохранением логов.
echo ""
echo "[simple-helper] Running switch for $HOST_ARG..."
SWITCH_LOG="/tmp/switch-$(date +%s).log"
echo "[simple-helper] Logs will be saved to $SWITCH_LOG"

  if sudo nixos-rebuild switch --flake "$FLAKE_REF#$HOST_ARG" 2>&1 | tee "$SWITCH_LOG"; then
    switch_status=${PIPESTATUS[0]}
    if [ "$switch_status" -ne 0 ]; then
      echo "[simple-helper] ERROR: nixos-rebuild switch failed (see $SWITCH_LOG)" >&2
      exit "$switch_status"
    fi
    echo "[simple-helper] Switch completed successfully."

    # Home-manager activation performed during nixos-rebuild may have written
    # files into the user's $HOME as root (this happens when the command is
    # executed via sudo). Fix common Emacs-related paths so files are owned by
    # the user — otherwise Emacs warns that modules are "not owned by current
    # user" and falls back to system modules.
    echo "[simple-helper] Ensuring ownership of Emacs user files in $HOME"
    if sudo test -d "$HOME/.config/emacs" >/dev/null 2>&1; then
      # Change owner only (avoid specifying group which may not exist on some systems)
      sudo chown -R "$USER" "$HOME/.config/emacs" || true
    fi
    # Also adjust auxiliary pro-emacs state/cache dirs if present
    if sudo test -d "$HOME/.local/state/pro-emacs" >/dev/null 2>&1; then
      sudo chown -R "$USER" "$HOME/.local/state/pro-emacs" || true
    fi
    if sudo test -d "$HOME/.cache/pro-emacs" >/dev/null 2>&1; then
      sudo chown -R "$USER" "$HOME/.cache/pro-emacs" || true
    fi

  # Пост-обработка: установить локальные утилиты в ~/bin чтобы были в PATH
  deploy_local_scripts(){
    SRC_DIR="$PWD"
    DEST_DIR="$HOME/bin"
    mkdir -p "$DEST_DIR"
    if [ -d "$SRC_DIR/bin" ]; then
      echo "[simple-helper] Installing local scripts to $DEST_DIR"
      for f in "$SRC_DIR"/bin/*; do
        if [ -f "$f" ]; then
          cp -pf "$f" "$DEST_DIR/"
          chmod +x "$DEST_DIR/$(basename "$f")"
          echo "[simple-helper] Installed $(basename "$f")"
        fi
      done
    fi

    # Ensure ~/bin is in PATH for interactive shells: add to ~/.profile if missing
    if ! rg -q "\$HOME/bin" "$HOME/.profile" 2>/dev/null; then
      echo "[simple-helper] Adding \$HOME/bin to PATH in ~/.profile"
      cat >> "$HOME/.profile" <<'EOF'
# Add user bin to PATH
if [ -d "$HOME/bin" ] && ! echo "$PATH" | grep -q "$HOME/bin"; then
  PATH="$HOME/bin:$PATH"
fi
EOF
    fi
  }

  # Запускаем деплой от имени текущего пользователя
  deploy_local_scripts || true

  exit 0
fi

echo ""
echo "=== Рекомендуемый способ активации ==="
echo ""
echo "# Вариант 1: boot (безопасно, активируется при reboot)"
echo "  sudo nixos-rebuild boot --flake '$FLAKE_REF#$HOST_ARG'"
echo "  sudo reboot"
echo ""
echo "# Вариант 2: switch (риск race condition, но быстрее)"
echo "  sudo nixos-rebuild switch --flake '$FLAKE_REF#$HOST_ARG'"
echo ""
echo "Выберите способ и выполните вручную."
