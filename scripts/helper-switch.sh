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

  # GIT_TERMINAL_PROMPT=0 — не висеть на запросе credentials для HTTPS-сабмодулей,
  # у которых нет credential helper.
  #
  # Главное правило: ЛЮБАЯ проблема с submodule update НЕ ВАЛИТ switch.
  # Nix-рецепты читают локальный submodules/<name> (см. nix/emacs-recipes/*.nix),
  # а не remote — поэтому можно собирать на старом HEAD.
  #
  # Почему именно последовательно + per-job timeout:
  #   - `git submodule update` по умолчанию гоняет 8 параллельных воркеров,
  #     что на github/codeberg упирается в rate-limit и доходит до 60+ секунд
  #     на merge-фазе (диагностика 2026-06-13: timeout 60 = exit, ровно 60с висит).
  #   - один сабмодуль fetch укладывается в 4–22с; merge в локальный HEAD <2с.
  #   - 11 submodules × ~15с = ~165с в худшем случае, приемлемо.
  #
  # Если fetch/merge упал — пишем WARNING и идём дальше. Локальный HEAD
  # используется как fallback (он уже на свежем состоянии после предыдущего
  # успешного update, либо на initial commit — в обоих случаях валиден для сборки).
  export GIT_TERMINAL_PROMPT=0
  echo "[simple-helper] Updating submodules (sequential, 20s fetch + 10s merge each)..."
  failed_subs=()
  updated_count=0
  for sub in $(git submodule foreach -q 'echo $sm_path'); do
    name=$(basename "$sub")
    # 1) fetch с timeout (подавляем вывод fetch — он шумный, логируем только статус)
    if ! timeout 20 git -C "$sub" fetch origin >/dev/null 2>&1; then
      echo "[simple-helper] WARNING: $name fetch failed/timeout — using local HEAD" >&2
      failed_subs+=("$name")
      continue
    fi
    # 2) merge в локальный HEAD с timeout.
    # `git submodule update --remote <path>` мержит remote-tracking branch
    # в локальный HEAD. Если merge не нужен (уже на свежем коммите) — exit 0 за <1с.
    if ! timeout 10 git submodule update --remote "$sub" 2>&1 \
         | sed "s/^/[simple-helper] submod[$name]: /"; then
      echo "[simple-helper] WARNING: $name merge failed/timeout — using local HEAD" >&2
      failed_subs+=("$name")
      continue
    fi
    updated_count=$((updated_count + 1))
  done
  if [ "${#failed_subs[@]}" -gt 0 ]; then
    echo "[simple-helper] These submodules were NOT updated (kept local HEAD):" >&2
    printf '  - %s\n' "${failed_subs[@]}" >&2
    echo "[simple-helper] Common causes: codeberg/github rate-limit, network timeout." >&2
    echo "[simple-helper] Continuing switch — Nix recipes will use whatever is in submodules/." >&2
  fi
  echo "[simple-helper] Submodules step finished: $updated_count updated, ${#failed_subs[@]} skipped."
fi

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
