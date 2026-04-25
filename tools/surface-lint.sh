#!/usr/bin/env bash
set -euo pipefail

# surface-lint: ensure SURFACE.md exists and HOLO.md referenced proofs present
root="$(cd "$(dirname "$0")/.." && pwd)"

if [ ! -f "$root/SURFACE.md" ]; then
  echo "SURFACE.md missing — create docs/SURFACE.md or SURFACE.md at repo root" >&2
  exit 2
fi

echo "SURFACE.md found"

# If called with --check-style or --enforce-style, scan strict paths for docstring headers
if [ "${1:-}" = "--check-style" ] || [ "${1:-}" = "--enforce-style" ]; then
  MODE=$1
  echo "Checking style in strict paths..."
  warn=0
  # minimal set of strict paths; keep small to avoid noise
  paths=("$root/nixos/modules" "$root/modules" "$root/emacs/base")
  for p in "${paths[@]}"; do
    if [ -d "$p" ]; then
      while IFS= read -r -d '' f; do
        # check for docstring markers (Назначение|Инварианты|Побочные эффекты|Контракт|Проверка)
        if ! rg -q "Назначение:|Инварианты:|Побочные эффекты:|Контракт:|Проверка:" "$f" 2>/dev/null; then
          echo "WARNING: missing docstring sections in $f" >&2
          warn=1
        fi
        # check for Russian comments presence
        if ! rg -q "[А-Яа-яЁё]" "$f" 2>/dev/null; then
          echo "WARNING: no Cyrillic text found in $f (expected Russian docs)" >&2
          warn=1
        fi
      done < <(find "$p" -type f -name "*.nix" -print0)
    fi
  done
  if [ $warn -ne 0 ]; then
    if [ "$MODE" = "--enforce-style" ]; then
      echo "surface-lint: style checks failed" >&2
      exit 4
    else
      echo "surface-lint: style checks produced warnings (use --enforce-style to make them fatal)" >&2
      exit 0
    fi
  fi
  echo "Style checks: OK"
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
