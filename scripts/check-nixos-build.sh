#!/usr/bin/env bash
set -euo pipefail
# Build NixOS configurations from this flake without sudo.
# Usage: ./scripts/check-nixos-build.sh [cf19|huawei|all]

target=${1:-all}

build_one() {
  local host=$1
  echo "Building flake target: .#nixosConfigurations.${host}.config.system.build.toplevel"
  if ! command -v nix >/dev/null 2>&1; then
    echo "nix command not found in PATH" >&2
    return 2
  fi
  if ! nix build ".#nixosConfigurations.${host}.config.system.build.toplevel"; then
    echo "Warning: building host ${host} failed. This may be due to config conflicts; continuing with opencode app build." >&2
    return 1
  fi
}

build_opencode_app() {
  echo "Building flake app: .#apps.x86_64-linux.opencode-release"
  if ! command -v nix >/dev/null 2>&1; then
    echo "nix command not found in PATH" >&2
    return 2
  fi
  nix build .#apps.x86_64-linux.opencode-release
}

case "$target" in
  cf19)
    build_one cf19
    ;;
  huawei)
    build_one huawei
    ;;
  all)
    build_one cf19
    build_one huawei
    ;;
  opencode-release)
    build_opencode_app
    ;;
  *)
    echo "Unknown target: $target" >&2
    exit 2
    ;;
esac

echo "Done"
