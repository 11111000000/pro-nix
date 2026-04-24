#!/usr/bin/env bash
set -euo pipefail

# Simple holo verify: run contract tests referenced in HOLO.md and all scripts in tests/contract
root="$(cd "$(dirname "$0")/.." && pwd)"
echo "Running holo verification from $root"

shopt -s nullglob
for t in "$root"/tests/contract/*; do
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
