#!/usr/bin/env bash
# set -euo pipefail

# Usage: switch.sh [HOST]
# Safe nixos-rebuild with BOOT as primary strategy (not switch).
# This avoids the dbus/polkit race that causes "Sender is not authorized" errors.

HOST_ARG="${1:-}"
HOST_ARG="${HOST_ARG#HOST=}"

if [ -z "$HOST_ARG" ]; then
  if [ -r /etc/hostname ]; then
    HOST_ARG=$(</etc/hostname)
  elif command -v hostname >/dev/null 2>&1; then
    HOST_ARG=$(hostname -s 2>/dev/null || hostname 2>/dev/null || true)
  fi
fi

if [ -z "$HOST_ARG" ]; then
  echo "No hostname. Run: helper-switch.sh <host>" >&2
  exit 1
fi

if [ ! -f "./hosts/$HOST_ARG/configuration.nix" ]; then
  echo "No config: ./hosts/$HOST_ARG/configuration.nix" >&2
  exit 1
fi

echo "[helper-switch] started for host: $HOST_ARG"

# Strategy: Use boot instead of switch to avoid dbus/polkit race
# This activates the new generation on REBOOT, not immediately.
do_boot() {
  local attempt=0
  local max_attempts=2
  
  while [ $attempt -lt $max_attempts ]; do
    attempt=$((attempt + 1))
    echo "[helper-switch] attempt $attempt/$max_attempts: nixos-rebuild boot..." >&2
    
    if nixos-rebuild boot --flake ".#$HOST_ARG" 2>&1; then
      echo "[helper-switch] boot successful. Will reboot now." >&2
      echo "[helper-switch] Run: sudo reboot to activate new generation" >&2
      return 0
    fi
    
    echo "[helper-switch] boot attempt $attempt failed" >&2
    sleep 2
  done
  
  return 1
}

# Main
if [ "$(id -u)" -eq 0 ]; then
  if do_boot; then
    echo "[helper-switch] Done. Reboot manually: sudo reboot" >&2
  else
    echo "[helper-switch] boot failed. Check logs." >&2
    exit 1
  fi
else
  # Use sudo
  if sudo nixos-rebuild boot --flake ".#$HOST_ARG" 2>&1; then
    echo "[helper-switch] boot successful. Rebooting..." >&2
    sudo reboot
  else
    echo "[helper-switch] boot failed." >&2
    exit 1
  fi
fi