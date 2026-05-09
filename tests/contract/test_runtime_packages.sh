#!/usr/bin/env bash
set -euo pipefail

# Contract test: ensure minimal runtime packages are present in toplevel
# Usage: run from repository root; requires nix with flakes enabled.

HOST=${1:-huawei}

builder=(nix --extra-experimental-features nix-command --extra-experimental-features flakes)

echo "Building toplevel for host: $HOST"
out=$("${builder[@]}" build --print-out-paths ".#nixosConfigurations.$HOST.config.system.build.toplevel" --no-link)
if [ -z "$out" ]; then
  echo "Build failed or returned empty path" >&2
  exit 2
fi

echo "Toplevel derivation path: $out"
echo -n "Checking that pi is present in the evaluated package list... "
pi_pkg=$(nix eval --json ".#nixosConfigurations.$HOST.config.environment.systemPackages" 2>/dev/null | jq -r '.[] | select(test("pi-coding-agent"))' | head -n1)
if [ -z "$pi_pkg" ]; then
  echo "MISSING" >&2
  exit 4
fi
echo "found"

echo -n "Checking that pi starts... "
if "$pi_pkg/bin/pi" --help >/dev/null 2>&1; then
  echo "ok"
else
  echo "FAILED" >&2
  echo "pi wrapper does not start on NixOS" >&2
  exit 5
fi

echo "Runtime package check: OK"
