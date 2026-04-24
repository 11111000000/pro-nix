#!/usr/bin/env bash
set -euo pipefail

# surface-lint: ensure SURFACE.md exists and HOLO.md referenced proofs present
root="$(cd "$(dirname "$0")/.." && pwd)"

if [ ! -f "$root/SURFACE.md" ]; then
  echo "SURFACE.md missing — create docs/SURFACE.md or SURFACE.md at repo root" >&2
  exit 2
fi

echo "SURFACE.md found"

# Quick check: ensure HOLO.md proof commands exist in scripts or tests
grep -Eo "\btests/contract/[^[:space:]']+" "$root/HOLO.md" | sort -u | while read -r f; do
  if [ ! -f "$root/$f" ]; then
    echo "Referenced proof missing: $f" >&2
    exit 3
  else
    echo "Proof present: $f"
  fi
done

echo "surface-lint: OK"
