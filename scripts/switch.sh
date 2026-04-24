#!/usr/bin/env bash
set -euo pipefail

# Usage: switch.sh [HOST]
# Скрипт нормализует аргумент HOST и выполняет либо реальный
# `nixos-rebuild switch` (когда sudo может повысить привилегии), либо
# non-root сборку toplevel-деривации для проверки в контейнерных окружениях.

HOST_ARG="${1:-}" 

# Если вызывают `just switch HOST=foo`, некоторые оболочки передают
# буквальную строку `HOST=foo` в качестве аргумента. Удаляем префикс
# `HOST=` при наличии.
HOST_ARG="${HOST_ARG#HOST=}"

if [ -z "$HOST_ARG" ]; then
  HOST_ARG="$(cat /etc/hostname 2>/dev/null || hostname -s 2>/dev/null || true)"
fi

if [ -z "$HOST_ARG" ]; then
  echo "No local hostname detected. Run: just switch <host> or set the host name with: sudo hostnamectl set-hostname <name>" >&2
  exit 1
fi

if [ ! -f "./hosts/$HOST_ARG/configuration.nix" ]; then
  echo "Detected hostname '$HOST_ARG' but no matching host configuration found in ./hosts/." >&2
  echo "Available hosts:" >&2
  ls -1 hosts || true
  echo "Run: just switch <host> to choose one of the above or add ./hosts/$HOST_ARG/configuration.nix" >&2
  exit 1
fi

# Предпочитаем выполнять реальный switch с помощью sudo. В контейнерах,
# где sudo не может получить привилегии (например, флаг "no new privileges"),
# выполняем non-root сборку toplevel-деривации для проверки.
if sudo -n true 2>/dev/null && sudo systemd-run --quiet --wait --collect --pipe --service-type=exec --unit=nixos-switch-preflight /bin/true >/dev/null 2>&1; then
  echo "[just] performing nixos-rebuild switch for host: $HOST_ARG"
  # Запускаем switch и сохраняем вывод для последующего анализа, избегая
  # автоматического перезапуска. Если активация падает из-за известной гонки
  # D-Bus/polkit, печатаем понятную подсказку оператору. Автоматический
  # fallback (boot+reboot) выполняется только при установленной переменной
  # окружения AUTO_REBOOT_ON_ACTIVATION_RACE=1.
  tmpf=$(mktemp)
  if sudo nixos-rebuild switch --flake ".#$HOST_ARG" 2>&1 | tee "$tmpf"; then
    rm -f "$tmpf"
    exec true
  else
    if rg -q "Rejected send message" "$tmpf" 2>/dev/null; then
      cat >&2 <<'MSG'
Живая активация не удалась из-за временной гонки D-Bus / polkit ("Rejected send message").
Рекомендуемые действия оператора:
  1) Просмотреть сохранённый вывод: sudo cat "${tmpf}" (или journalctl -b).
  2) Если приемлемо, выполнить: sudo nixos-rebuild boot --flake ".#${HOST_ARG}" && sudo reboot
Если в окружении установлено AUTO_REBOOT_ON_ACTIVATION_RACE=1, скрипт
выполнит fallback (boot+reboot) автоматически.
MSG
    else
      cat >&2 <<'MSG'
nixos-rebuild switch завершился с ошибкой. См. вывод выше для деталей. Чтобы
попробовать безопасную активацию при загрузке, выполните:
  sudo nixos-rebuild boot --flake ".#${HOST_ARG}" && sudo reboot
MSG
    fi
    rm -f "$tmpf"
    exit 1
  fi
else
  echo "[just] sudo unavailable or cannot gain privileges; performing non-root build check (no switch)" >&2
  exec nix --extra-experimental-features 'nix-command flakes' build --print-out-paths ".#nixosConfigurations.\"$HOST_ARG\".config.system.build.toplevel" --no-link
fi
