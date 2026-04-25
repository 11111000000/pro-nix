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


# Use a single ripgrep invocation and process matches deterministically.
echo "## Raw matches (file:line:match)" >> "$out_file"
echo >> "$out_file"
rg -n --hidden --no-ignore -S "lib.mkOption|lib.mkEnableOption|lib.mkOptionName|options =|options\." --glob '!./.git/*' || true | while IFS= read -r ln; do
  file=$(echo "$ln" | cut -d: -f1)
  lineno=$(echo "$ln" | cut -d: -f2)
  match=$(echo "$ln" | cut -d: -f3-)
  echo "- $file:$lineno — $match" >> "$out_file"
done

echo >> "$out_file"
echo "## Context snippets" >> "$out_file"
echo >> "$out_file"
rg -n --hidden --no-ignore -S "lib.mkOption|lib.mkEnableOption|lib.mkOptionName|options =|options\." --glob '!./.git/*' || true | cut -d: -f1,2 | sort -u | while IFS= read -r ln; do
  file=$(echo "$ln" | cut -d: -f1)
  lineno=$(echo "$ln" | cut -d: -f2)
  echo "### $file:$lineno" >> "$out_file"
  echo '```nix' >> "$out_file"
  start=$((lineno>3?lineno-2:1))
  end=$((lineno+10))
  sed -n "${start},${end}p" "$file" >> "$out_file" || true
  echo '```' >> "$out_file"
  echo >> "$out_file"
done

echo "Generated $out_file"
