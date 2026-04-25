#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../../.." && pwd)"

echo "Running basic nix-eval unit tests"

# Keep the unit test small and deterministic: verify that the repo exposes a
# flake entrypoint and that nix can evaluate a trivial expression.

NIX="nix"

echo -n "Checking flake file... "
if [ -f "$root/flake.nix" ]; then
  echo "ok"
else
  echo "flake.nix missing" >&2
  exit 2
fi

echo -n "Checking basic nix eval... "
# Use --json to avoid raw string coercion problems in older nix
if $NIX eval --json --expr '{ r = 1 + 1; }' >/dev/null 2>&1; then
  echo "ok"
else
  echo "basic nix eval failed" >&2
  exit 3
fi

echo "unit nix-eval basic: OK"
