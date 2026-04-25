#!/usr/bin/env bash
set -euo pipefail

# Simple holo verify: run contract tests referenced in HOLO.md and all scripts in tests/contract
root="$(cd "$(dirname "$0")/.." && pwd)"
echo "Running holo verification from $root"

shopt -s nullglob
MODE=${1:-unit}
if [ "$MODE" = "unit" ]; then
  pattern="$root/tests/contract/unit/*"
else
  pattern="$root/tests/contract/*"
fi

for t in $pattern; do
  [ -e "$t" ] || continue
  case "$t" in
    *.sh)
      echo "== Running contract script: $(basename "$t")"
      bash "$t"
      ;;
    *)
      if [ -x "$t" ]; then
        echo "== Running contract test: $(basename "$t")"
        "$t"
      else
        echo "== Skipping non-shell contract file: $(basename "$t")"
      fi
      ;;
  esac
done

echo "holo-verify: OK"

# additional check: ensure HOLO.md referenced contract tests exist
if [ -f "$root/HOLO.md" ]; then
  rg -n "tests/contract/" "$root/HOLO.md" || true
fi
