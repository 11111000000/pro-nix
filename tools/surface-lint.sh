#!/usr/bin/env bash
set -euo pipefail

# surface-lint: ensure SURFACE.md exists and HOLO.md referenced proofs present
root="$(cd "$(dirname "$0")/.." && pwd)"

if [ ! -f "$root/SURFACE.md" ]; then
  echo "SURFACE.md missing — create docs/SURFACE.md or SURFACE.md at repo root" >&2
  exit 2
fi

echo "SURFACE.md found"

# If called with --check-comments, ensure modules contain literary headers
if [ "${1:-}" = "--check-comments" ]; then
  echo "Checking modules for literary headers..."
  missing=0
  for f in "$root"/modules/*.nix; do
    [ -e "$f" ] || continue
    if ! rg -q '^# Название:' "$f" 2>/dev/null; then
      echo "MISSING HEADER: $f" >&2
      missing=1
    fi
  done
  if [ $missing -ne 0 ]; then
    echo "surface-lint: missing headers" >&2
    exit 4
  fi
  echo "All modules contain literary headers"
  exit 0
fi

# Quick check: ensure HOLO.md proof commands exist in scripts or tests
if [ -f "$root/HOLO.md" ]; then
  grep -Eo "tests/contract/[^[:space:]'\`]+" "$root/HOLO.md" | sort -u | while read -r f; do
    f="$(printf '%s' "$f" | tr -d '\`\"')"
    if [ ! -f "$root/$f" ]; then
      echo "Referenced proof missing: $f" >&2
      exit 3
    else
      echo "Proof present: $f"
    fi
  done
fi

echo "surface-lint: OK"
