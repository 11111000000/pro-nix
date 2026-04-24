#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
surface="$root/SURFACE.md"

if [[ ! -f "$surface" ]]; then
  echo "SURFACE.md not found" >&2
  exit 2
fi

# Basic lint rules:
# - Each item starts with '- Name:'
# - If Stability: [FROZEN] is present, Proof: must follow within next 6 lines

errs=0
nl=0
while IFS= read -r line; do
  nl=$((nl+1))
  if [[ "$line" =~ ^-\ Name: ]]; then
    # look ahead for Stability and Proof
    block="$(tail -n +$((nl)) "$surface" | head -n 8)"
    if grep -q '\[FROZEN\]' <<<"$block"; then
      if ! grep -q -E 'Proof:\s*' <<<"$block"; then
        echo "SURFACE lint: [FROZEN] item at line $nl missing Proof" >&2
        errs=$((errs+1))
      fi
    fi
  fi
done < "$surface"

if [[ $errs -gt 0 ]]; then
  echo "SURFACE lint: $errs error(s)" >&2
  exit 1
fi

echo "SURFACE lint: OK"
