#!/usr/bin/env bash
set -euo pipefail

# Проверка: все модули должны содержать литературный заголовок ("# Название:")
root="$(cd "$(dirname "$0")/../.." && pwd)"
missing=0
for f in "$root"/modules/*.nix; do
  [ -e "$f" ] || continue
  if ! rg -q '^# Название:' "$f" 2>/dev/null; then
    echo "MISSING HEADER: $f" >&2
    missing=1
  fi
done
if [ $missing -ne 0 ]; then
  echo "One or more modules lack literary headers" >&2
  exit 2
fi
echo "All module headers present"
