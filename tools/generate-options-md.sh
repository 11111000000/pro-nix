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
while IFS= read -r ln; do
  file=$(echo "$ln" | cut -d: -f1)
  lineno=$(echo "$ln" | cut -d: -f2)
  match=$(echo "$ln" | cut -d: -f3-)
  case "$lineno" in
    ''|*[!0-9]*) continue ;;
  esac
  echo "- $file:$lineno — $match" >> "$out_file"
done < <(rg -n --hidden --no-ignore -S "lib.mkOption|lib.mkEnableOption|lib.mkOptionName|options =|options\." --glob '!./.git/*' || true)

echo >> "$out_file"
echo "## Context snippets" >> "$out_file"
echo >> "$out_file"
while IFS= read -r ln; do
  file=$(echo "$ln" | cut -d: -f1)
  lineno=$(echo "$ln" | cut -d: -f2)
  case "$lineno" in
    ''|*[!0-9]*) continue ;;
  esac
  echo "### $file:$lineno" >> "$out_file"
  echo '```nix' >> "$out_file"
  start=$((lineno>3?lineno-2:1))
  end=$((lineno+10))
  sed -n "${start},${end}p" "$file" >> "$out_file" || true
  echo '```' >> "$out_file"
  echo >> "$out_file"
done < <(rg -n --hidden --no-ignore -S "lib.mkOption|lib.mkEnableOption|lib.mkOptionName|options =|options\." --glob '!./.git/*' | cut -d: -f1,2 | sort -u || true)

echo "## Extracted option defaults (heuristic)" >> "$out_file"
echo >> "$out_file"
while IFS= read -r ln; do
  file=$(echo "$ln" | cut -d: -f1)
  lineno=$(echo "$ln" | cut -d: -f2)
  case "$lineno" in
    ''|*[!0-9]*) continue ;;
  esac
  echo "### $file:$lineno" >> "$out_file"
  # extract block from lineno to next '};' (heuristic)
  awk "NR>=$lineno{print} /\};/{exit}" "$file" > /tmp/_opt_block.$$ || true
  echo '```nix' >> "$out_file"
  cat /tmp/_opt_block.$$ >> "$out_file" || true
  echo '```' >> "$out_file"
  # try to find default and type within the block
  dflt=$(rg -n "default\s*=\s*" /tmp/_opt_block.$$ -o --no-line-number || true)
  typ=$(rg -n "type\s*=\s*" /tmp/_opt_block.$$ -o --no-line-number || true)
  if [ -n "$dflt" ]; then
    echo "Default: $dflt" >> "$out_file"
  fi
  if [ -n "$typ" ]; then
    echo "Type: $typ" >> "$out_file"
  fi
  echo >> "$out_file"
  rm -f /tmp/_opt_block.$$ || true
done < <(rg -n --hidden --no-ignore -S "lib.mkOption" --glob '!./.git/*' || true)

echo "Generated $out_file"
