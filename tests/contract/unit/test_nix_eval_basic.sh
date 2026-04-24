#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"

echo "Running basic nix-eval unit tests"

# Check some expected config values via nix eval
NIX="nix --extra-experimental-features 'nix-command flakes'"

echo -n "Checking pro-peer.enable exists... "
if ${NIX} eval --raw .#nixosConfigurations.huawei.config.pro-peer.enable >/dev/null 2>&1; then
  echo "ok"
else
  echo "MISSING" >&2
  exit 2
fi

echo -n "Checking pro-peer.keysGpgPath default... "
val=$(${NIX} eval --raw .#nixosConfigurations.huawei.config.pro-peer.keysGpgPath 2>/dev/null || true)
if [ -n "$val" ]; then
  echo "ok -> $val"
else
  echo "missing or empty" >&2
  exit 3
fi

echo "unit nix-eval basic: OK"
