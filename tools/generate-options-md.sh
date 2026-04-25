#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
out_file="$root/docs/analyse/options.md"
mkdir -p "$(dirname "$out_file")"
: > "$out_file"

echo "# Options Registry" >> "$out_file"
echo >> "$out_file"
echo "This file summarises option surfaces from the repository's key modules." >> "$out_file"
echo >> "$out_file"

files=(
  "modules/pro-peer.nix"
  "emacs/home-manager.nix"
  "modules/headscale.nix"
  "nixos/modules/opencode.nix"
  "nixos/modules/opencode-config.nix"
  "nixos/modules/zram-slice.nix"
)

for rel in "${files[@]}"; do
  path="$root/$rel"
  [ -f "$path" ] || continue
  echo "## $rel" >> "$out_file"
  echo >> "$out_file"
  awk '
    /options[[:space:]]*=|lib\.mkOption|lib\.mkEnableOption|lib\.mkOptionName/ {p=1}
    p { print }
    p && /^ *};/ { p=0; print "" }
  ' "$path" >> "$out_file"
  echo >> "$out_file"
done

echo "Generated $out_file"
