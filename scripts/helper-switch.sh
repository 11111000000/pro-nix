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

  # Retry loop with exponential backoff
  local attempt=0
  local max_attempts=3
  local delay=1

  while [ $attempt -lt $max_attempts ]; do
    attempt=$((attempt+1))
    if nixos-rebuild switch --flake ".#$HOST_ARG" 2>&1 | tee "$tmpf"; then
      rm -f "$tmpf"
      exec true
    fi

    if has_pattern_in_file "Rejected send message\|Sender is not authorized to send message" "$tmpf"; then
      if [ $attempt -lt $max_attempts ]; then
        echo "[just] attempt $attempt/$max_attempts failed, waiting ${delay}s before retry..." >&2
        sleep $delay
        delay=$((delay * 2))
        continue
      else
        while IFS= read -r _line; do printf '%s\n' "$_line" >&2; done <<'MSG'
Живая активация не удалась после $max_attempts попыток из-за гонки D-Bus / polkit.
Рекомендуемые действия:
  1) sudo nixos-rebuild boot --flake ".#${HOST_ARG}" && sudo reboot
MSG
        rm -f "$tmpf"
        exit 1
      fi
    else
      while IFS= read -r _line; do printf '%s\n' "$_line" >&2; done <<'MSG'
nixos-rebuild switch завершился с ошибкой.
Используйте: sudo nixos-rebuild boot --flake ".#${HOST_ARG}" && sudo reboot
MSG
      rm -f "$tmpf"
      exit 1
    fi
  done

  rm -f "$tmpf"
  exit 1
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

  # Wait for system bus to be responsive before attempting a live switch.
  wait_for_system_bus() {
    local timeout=${1:-30}
    local waited=0
    local busctl_cmd=""
    if command -v busctl >/dev/null 2>&1; then
      busctl_cmd=busctl
    elif [ -x "/run/current-system/sw/bin/busctl" ]; then
      busctl_cmd="/run/current-system/sw/bin/busctl"
    fi

    while [ $waited -lt $timeout ]; do
      if [ -S /run/dbus/system_bus_socket ]; then
        if [ -n "$busctl_cmd" ]; then
          if sudo "$busctl_cmd" --system --no-status identity >/dev/null 2>&1; then
            return 0
          fi
        else
          # socket exists and we have no busctl; assume bus may be up
          return 0
        fi
      fi
      sleep 1
      waited=$((waited+1))
    done
    return 1
  }

if ! wait_for_system_bus 30; then
    echo "[just] system bus not responsive after wait; skipping live switch to avoid activation race" >&2
    echo "Run: sudo nixos-rebuild boot --flake \".#${HOST_ARG}\" && sudo reboot" >&2
    rm -f "$tmpf"
    exit 1
  fi

  # Retry loop with exponential backoff to handle transient dbus authorization failures
  local attempt=0
  local max_attempts=3
  local delay=1

  while [ $attempt -lt $max_attempts ]; do
    attempt=$((attempt+1))
    if sudo nixos-rebuild switch --flake ".#$HOST_ARG" 2>&1 | tee "$tmpf"; then
      rm -f "$tmpf"
      exec true
    fi

    # Check for activation race errors: "Rejected send message" OR "Sender is not authorized to send message"
    if has_pattern_in_file "Rejected send message\|Sender is not authorized to send message" "$tmpf"; then
      if [ $attempt -lt $max_attempts ]; then
        echo "[just] attempt $attempt/$max_attempts failed, waiting ${delay}s before retry..." >&2
        sleep $delay
        delay=$((delay * 2))
        continue
      else
        # All retries exhausted - show error and suggest boot fallback
        while IFS= read -r _line; do printf '%s\n' "$_line" >&2; done <<'MSG'
Живая активация не удалась после $max_attempts попыток из-за временной гонки D-Bus / polkit.
Рекомендуемые действия оператора:
  1) Просмотреть вывод: sudo less "${tmpf}" (или journalctl -b -f)
  2) Выполнить безопасный откат: sudo nixos-rebuild boot --flake ".#${HOST_ARG}" && sudo reboot
MSG
        rm -f "$tmpf"
        exit 1
      fi
    else
      # Non-race error - exit immediately
      while IFS= read -r _line; do printf '%s\n' "$_line" >&2; done <<'MSG'
nixos-rebuild switch завершился с ошибкой.
Для безопасной активации при загрузке выполните:
  sudo nixos-rebuild boot --flake ".#${HOST_ARG}" && sudo reboot
MSG
      rm -f "$tmpf"
      exit 1
    fi
  done

  # Should not reach here, but safety net
  echo "[just] все попытки исчерпаны, выход с ошибкой" >&2
  rm -f "$tmpf"
  exit 1
else
  # Fallback for non-root or non-privileged environment
  echo "[just] sudo unavailable or cannot gain privileges; performing non-root build check (no switch)" >&2
  exec nix --extra-experimental-features 'nix-command flakes' build --print-out-paths ".#nixosConfigurations.\"$HOST_ARG\".config.system.build.toplevel" --no-link
fi
