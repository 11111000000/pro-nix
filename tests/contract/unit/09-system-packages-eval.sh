#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$root"

echo "09: evaluate system-packages.nix directly (host-independent)"

# This test catches a common regression where system-packages.nix accidentally
# returns a function/thunk instead of a derivation in the final list.
# It uses <nixpkgs> for fast, local validation and does not depend on flake host eval.

export NIXPKGS_ALLOW_UNFREE=1

expr='let
  pkgs = import <nixpkgs> { system = "x86_64-linux"; config.allowUnfree = true; };
  lst = (import ./system-packages.nix { inherit pkgs; emacsPkg = pkgs.emacs; enableOptional = true; }).packages;
in builtins.map (x: x.name or "<no-name>") lst'

echo -n "Evaluating list shape... "
out=$(nix eval --impure --json --expr "$expr" 2>/dev/null || true)
if [ -z "$out" ]; then
  echo "FAILED" >&2
  echo "system-packages.nix evaluation returned empty output or failed" >&2
  exit 2
fi
echo "ok"

echo "$out" | jq -r '.[]' > /tmp/_spkgs_names.$$ || true

for pkg in gh mc python3 htop pi; do
  echo -n "Checking for $pkg in system-packages list... "
  grep -Ei "$pkg" /tmp/_spkgs_names.$$ >/dev/null 2>&1 || {
    echo "FAILED" >&2
    echo "Expected package '$pkg' not found in system-packages.nix output" >&2
    rm -f /tmp/_spkgs_names.$$ || true
    exit 3
  }
  echo "ok"
done

rm -f /tmp/_spkgs_names.$$ || true
echo "09: OK"
