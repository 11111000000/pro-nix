#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../../.." && pwd)"
NIX="nix"

echo "04: opencode options checks"

val=$($NIX eval --json .#nixosConfigurations.huawei.config.home-manager.users.az.programs.opencode-bwrap.enable 2>/dev/null || true)
if [ "$val" != "true" ]; then
  echo "programs.opencode-bwrap.enable is not true for az: $val" >&2
  exit 3
fi

pkg=$($NIX eval --raw .#nixosConfigurations.huawei.config.home-manager.users.az.programs.opencode-bwrap.package 2>/dev/null || true)
if [ -z "$pkg" ]; then
  echo "programs.opencode-bwrap.package missing" >&2
  exit 4
fi

echo "04: OK"
