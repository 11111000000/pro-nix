#!/usr/bin/env bash
set -euo pipefail

# Contract test: ensure minimal runtime packages are present in toplevel
# Usage: run from repository root; requires nix with flakes enabled.

HOST=${1:-huawei}

builder="nix --extra-experimental-features 'nix-command flakes'"

echo "Building toplevel for host: $HOST"
out=$($builder build --print-out-paths ".#nixosConfigurations.$HOST.config.system.build.toplevel" --no-link)
if [ -z "$out" ]; then
  echo "Build failed or returned empty path" >&2
  exit 2
fi

echo "Toplevel derivation path: $out"

# The profile's /bin is at $out/bin or $out/sw/bin depending on the derivation shape.
check_bin_in_store() {
  local pkg=$1
  if ! ls "$out" | rg -q "bin|sw" >/dev/null 2>&1; then
    echo "Unexpected toplevel layout: listing $out:" >&2
    ls -la "$out" || true
    return 1
  fi
  # Search for the binary in the closure
  if nix-store -qR "$out" | xargs -r -n1 ls -d 2>/dev/null | rg -q "/bin/$pkg$"; then
    return 0
  fi
  return 1
}

for p in bash ssh; do
  echo -n "Checking for $p... "
  if check_bin_in_store "$p"; then
    echo "found"
  else
    echo "MISSING" >&2
    exit 3
  fi
done

echo "Runtime package check: OK"
