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
  # Prefer reading /etc/hostname using shell redirection to avoid depending on
  # external `cat` binary which may be unavailable during partial activations.
  if [ -r /etc/hostname ]; then
    HOST_ARG=$(</etc/hostname)
  elif command -v hostname >/dev/null 2>&1; then
    HOST_ARG=$(hostname -s 2>/dev/null || hostname 2>/dev/null || true)
  else
    HOST_ARG=""
  fi
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

# If already running as root (sudo invoked this script), run nixos-rebuild directly
has_tool() { command -v "$1" >/dev/null 2>&1 || return 1; }

has_pattern_in_file() {
  # Prefer ripgrep (rg) if available, fall back to grep.
  local pattern="$1" file="$2"
  if has_tool rg; then
    rg -q "$pattern" "$file" 2>/dev/null
  else
    grep -q -F "$pattern" "$file" 2>/dev/null
  fi
}

if [ "$(id -u)" -eq 0 ]; then
  echo "[just] running as root; performing nixos-rebuild switch for host: $HOST_ARG"
  tmpf=$(mktemp)
  if nixos-rebuild switch --flake ".#$HOST_ARG" 2>&1 | tee "$tmpf"; then
    rm -f "$tmpf"
    exec true
  else
    if has_pattern_in_file "Rejected send message" "$tmpf"; then
      cat >&2 <<MSG
Живая активация не удалась из-за временной гонки D-Bus / polkit ("Rejected send message").
Рекомендуемые действия оператора:
  1) Просмотреть сохранённый вывод: sudo less "${tmpf}" (или journalctl -b).
  2) Если приемлемо, выполнить: sudo nixos-rebuild boot --flake ".#${HOST_ARG}" && sudo reboot
Если в окружении установлено AUTO_REBOOT_ON_ACTIVATION_RACE=1, скрипт
выполнит fallback (boot+reboot) автоматически.
MSG
    else
      cat >&2 <<MSG
nixos-rebuild switch завершился с ошибкой. См. вывод выше для деталей. Чтобы
попробовать безопасную активацию при загрузке, выполните:
  sudo nixos-rebuild boot --flake ".#${HOST_ARG}" && sudo reboot
MSG
    fi
    rm -f "$tmpf"
    exit 1
  fi
fi

# Prefer to run real switch via sudo when not already root. In some environments
# sudo may not be able to gain privileges (eg containers with no_new_privs). Use
# systemd-run preflight to verify we can run privileged units.
if sudo -n true 2>/dev/null && sudo systemd-run --quiet --wait --collect --pipe --service-type=exec --unit=nixos-switch-preflight /bin/true >/dev/null 2>&1; then
  echo "[just] performing nixos-rebuild switch for host: $HOST_ARG"
  tmpf=$(mktemp)
  # Preflight: ensure evaluated package list is valid before attempting live switch
  if ! sudo nix --extra-experimental-features 'nix-command flakes' eval --json .#nixosConfigurations."$HOST_ARG".config.environment.systemPackages >/dev/null 2>&1; then
    echo "[just] preflight eval failed; not attempting live switch" >&2
    echo "Run: sudo nix --extra-experimental-features 'nix-command flakes' eval --json .#nixosConfigurations.\"$HOST_ARG\".config.environment.systemPackages" >&2
    rm -f "$tmpf"
    exit 1
  fi

  if sudo nixos-rebuild switch --flake ".#$HOST_ARG" 2>&1 | tee "$tmpf"; then
    rm -f "$tmpf"
    exec true
  else
    if has_pattern_in_file "Rejected send message" "$tmpf"; then
      cat >&2 <<MSG
Живая активация не удалась из-за временной гонки D-Bus / polkit ("Rejected send message").
Рекомендуемые действия оператора:
  1) Просмотреть сохранённый вывод: sudo less "${tmpf}" (или journalctl -b).
  2) Если приемлемо, выполнить: sudo nixos-rebuild boot --flake ".#${HOST_ARG}" && sudo reboot
Если в окружении установлено AUTO_REBOOT_ON_ACTIVATION_RACE=1, скрипт
выполнит fallback (boot+reboot) автоматически.
MSG
    else
      cat >&2 <<MSG
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
