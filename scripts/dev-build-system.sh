#!/usr/bin/env bash

set -euo pipefail

if [[ $# -gt 1 ]]; then
  printf 'Usage: %s [flake-attr]\n' "${0##*/}" >&2
  printf 'Default: nixosConfigurations.nixos.config.system.build.toplevel\n' >&2
  exit 1
fi

# Собирает текущую систему из flake-конфига в этом репозитории.
attr="${1:-nixosConfigurations.nixos.config.system.build.toplevel}"

exec nix build ".#${attr}"
