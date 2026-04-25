# Название: tools/generate-options-md.sh — Генерация документа опций в Markdown
# Summary (EN): Generate options registry as Markdown from modules
# Цель:
#   Собрать все опции из ключевых модулей и сгенерировать docs/analyse/options.md.
# Контракт:
#   Опции: нет
#   Побочные эффекты: создаёт docs/analyse/options.md.
# Предпосылки:
#   Требуется nix и доступ к модулям.
# Как проверить (Proof):
#   `./tools/generate-options-md.sh && head -20 docs/analyse/options.md`
# Last reviewed: 2026-04-25
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
