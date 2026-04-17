#!/usr/bin/env sh
set -eu

if [ ! -f ./local.nix ] && [ -f ./local.nix.example ]; then
  cp ./local.nix.example ./local.nix
  printf '%s\n' "Created local.nix from local.nix.example. Edit hostName before rebuild."
fi

exec sudo nixos-rebuild switch --flake .#pro
