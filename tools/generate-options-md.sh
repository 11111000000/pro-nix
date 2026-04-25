#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
out_file="$root/docs/analyse/options.md"
mkdir -p "$(dirname "$out_file")"
: > "$out_file"

echo "# Options Registry" >> "$out_file"
echo >> "$out_file"
echo "This file lists NixOS module option declarations (lib.mkOption, lib.mkEnableOption, options = { ... })." >> "$out_file"
echo >> "$out_file"

# Patterns to search for
patterns=("lib.mkOption" "lib.mkEnableOption" "lib.mkOptionName" "options =" "options.")

for pat in "${patterns[@]}"; do
  echo "## Matches for pattern: $pat" >> "$out_file"
  echo >> "$out_file"
  rg -n --hidden --no-ignore -S "$pat" --glob '!./.git/*' || true | while IFS= read -r ln; do
    file=$(echo "$ln" | cut -d: -f1)
    lineno=$(echo "$ln" | cut -d: -f2)
    echo "### $file:$lineno" >> "$out_file"
    echo '```nix' >> "$out_file"
    # print a small context window (lineno -2 .. lineno +6)
    start=$((lineno>3?lineno-2:1))
    end=$((lineno+6))
    sed -n "${start},${end}p" "$file" >> "$out_file" || true
    echo '```' >> "$out_file"
    echo >> "$out_file"
  done
done

echo "Generated $out_file"
