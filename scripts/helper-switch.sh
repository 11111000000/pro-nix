#!/usr/bin/env bash
# simple-helper-switch — быстрая активация перед switch
#
# Использует nixpkgs defaults напрямую (без кастомных модулей).
# Предлагает использовать boot для избежания race conditions при switch.
#
# Перед сборкой подтягивает свежий main/master для всех submodules
# (pro-tabs, carriage, telega, acapella, atlas, tao-theme, shaoline, ...),
# потому что nix/emacs-recipes/*.nix берут src = ../../submodules/<name>.
# Отключить автообновление: PRO_NIX_NO_SUBMODULE_UPDATE=1 just switch HOST

HOST_ARG="${1:-}"
HOST_ARG="${HOST_ARG#HOST=}"
FLAKE_REF="path:$PWD"

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
  exit 1
fi

echo "[simple-helper] Checking configuration for host: $HOST_ARG"

# Обновляем submodules до свежего main/master.
# Источник истины — submodules/, поэтому Nix-рецепты собирают пакеты отсюда.
if [ -z "${PRO_NIX_NO_SUBMODULE_UPDATE:-}" ]; then
  echo ""
  echo "[simple-helper] Updating submodules to remote main/master..."

  # Если в каком-то submodule есть локальные изменения — падаем громко,
  # чтобы случайно не затоптать работу пользователя.
  dirty=$(git submodule foreach --quiet 'git diff --quiet HEAD -- || echo $sm_name' 2>/dev/null | sed '/^$/d')
  if [ -n "$dirty" ]; then
    echo "[simple-helper] ERROR: submodules have uncommitted changes:" >&2
    echo "$dirty" | sed 's/^/  - /' >&2
    echo "[simple-helper] Commit/stash them or set PRO_NIX_NO_SUBMODULE_UPDATE=1" >&2
    exit 1
  fi

  if ! git submodule update --remote --merge 2>&1 | sed 's/^/[simple-helper] submod: /'; then
    echo "[simple-helper] ERROR: git submodule update --remote --merge failed" >&2
    exit 1
  fi
  echo "[simple-helper] Submodules are on fresh main/master."
fi

# Запуск switch с сохранением логов.
echo ""
echo "[simple-helper] Running switch for $HOST_ARG..."
SWITCH_LOG="/tmp/switch-$(date +%s).log"
echo "[simple-helper] Logs will be saved to $SWITCH_LOG"

if sudo nixos-rebuild switch --flake "$FLAKE_REF#$HOST_ARG" 2>&1 | tee "$SWITCH_LOG"; then
  echo "[simple-helper] Switch completed successfully."

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
