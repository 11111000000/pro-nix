#!/usr/bin/env bash
set -euo pipefail

# Usage: switch.sh [HOST]
# This helper normalizes the HOST argument and performs either a real
# `nixos-rebuild switch` (when sudo can elevate) or a non-root build of the
# toplevel derivation for verification in container environments.

HOST_ARG="${1:-}" 

# If called as `just switch HOST=foo` some shells pass the literal assignment
# into the recipe. Strip a leading `HOST=` if present.
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

# Prefer performing a real switch with sudo. In container environments where
# sudo cannot gain privileges (eg. "no new privileges" flag), fall back to a
# non-root build of the toplevel derivation for verification purposes.
if sudo -n true 2>/dev/null; then
  echo "[just] performing nixos-rebuild switch for host: $HOST_ARG"
  exec sudo nixos-rebuild switch --flake ".#$HOST_ARG"
else
  echo "[just] sudo unavailable or cannot gain privileges; performing non-root build check (no switch)" >&2
  exec nix --extra-experimental-features 'nix-command flakes' build --print-out-paths ".#nixosConfigurations.\"$HOST_ARG\".config.system.build.toplevel" --no-link
fi
