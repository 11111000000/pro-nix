#!/usr/bin/env bash
# Ensure we run under bash even if invoked via sh (e.g., org-babel)
if [ -z "${BASH_VERSION:-}" ]; then exec bash "$0" "$@"; fi
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
surface="$root/SURFACE.md"
[[ -f "$surface" ]] || { echo "SURFACE.md missing" >&2; exit 2; }

# Lint ensures each [FROZEN]/[FLUID] line has a name and optional path in parentheses
bad=0
dups=0
re='^-[[:space:]]+\[(FROZEN|FLUID)\][[:space:]]+[^()]+(\([^)]*\))?[[:space:]]*$'
declare -A names=()
while IFS= read -r line; do
  if grep -Eq '^-[[:space:]]+\[(FROZEN|FLUID)\][[:space:]]+[^()]+(\([^)]*\))?[[:space:]]*$' <<<"$line"; then
    # Extract normalized item name (strip status prefix and optional (path))
    name="$(sed -E 's/^-\s*\[(FROZEN|FLUID)\]\s*//; s/\s*\([^)]*\)\s*$//' <<<"$line" | sed -E 's/[[:space:]]+$//')"
    if [[ -n "$name" ]]; then
      if [[ -n "${names[$name]:-}" ]]; then
        echo "SURFACE LINT: duplicate item name: $name" >&2
        dups=$((dups+1))
      else
        names[$name]=1
      fi
    fi
  else
    echo "SURFACE LINT: suspicious line: $line" >&2
    bad=$((bad+1))
  fi
done < <(grep -E '^-\s*\[(FROZEN|FLUID)\]' "$surface" || true)

issues=$((bad+dups))
if [[ "$issues" -gt 0 ]]; then
  echo "SURFACE LINT: $issues issue(s) (${bad} format, ${dups} duplicate name[s])" >&2
  exit 1
fi

echo "SURFACE LINT: OK"
