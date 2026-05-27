#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$root"

echo "09: evaluate dev module package set (host-independent)"

# This test validates that a core module evaluates correctly.
# It uses <nixpkgs> for fast, local validation.

export NIXPKGS_ALLOW_UNFREE=1

expr='let
  pkgs = import <nixpkgs> { system = "x86_64-linux"; config.allowUnfree = true; };
  lst = (import ./modules/system-package-sets-dev.nix { inherit pkgs; }).devPackages;
in builtins.map (x: x.name or "<no-name>") lst'

echo -n "Evaluating list shape... "
out=$(nix eval --impure --json --expr "$expr" 2>/dev/null || true)
if [ -z "$out" ]; then
  echo "FAILED" >&2
  echo "dev module evaluation returned empty output or failed" >&2
  exit 2
fi
echo "ok"

echo "$out" | jq -r '.[]' > /tmp/_devpkg_names.$$ || true

for pkg in direnv bat git cmake; do
  echo -n "Checking for $pkg in dev packages list... "
  grep -Ei "$pkg" /tmp/_devpkg_names.$$ >/dev/null 2>&1 || {
    echo "FAILED" >&2
    echo "Expected package '$pkg' not found in dev module output" >&2
    rm -f /tmp/_devpkg_names.$$ || true
    exit 3
  }
  echo "ok"
done

rm -f /tmp/_devpkg_names.$$ || true
echo "09: OK"
