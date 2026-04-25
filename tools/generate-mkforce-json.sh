#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
out="$root/docs/analyse/mkforce-list.json"
mkdir -p "$(dirname "$out")"

echo "Generating mkForce usage list to $out"

echo '[' > "$out"
first=true
rg -n --hidden --no-ignore -S "lib\.mkForce" --glob '!./.git/*' | while IFS= read -r ln; do
  file=$(echo "$ln" | cut -d: -f1)
  lineno=$(echo "$ln" | cut -d: -f2)
  match=$(echo "$ln" | cut -d: -f3- | sed 's/"/\\"/g')
  snippet=$(sed -n "$lineno,$((lineno+4))p" "$file" | sed 's/"/\\"/g' | awk '{printf "%s\\n", $0}')
  if [ "$first" = true ]; then
    first=false
  else
    echo ',' >> "$out"
  fi
  printf '{"file":"%s","line":%s,"match":"%s","snippet":"%s"}' "$file" "$lineno" "$match" "$snippet" >> "$out"
done
echo ']' >> "$out"

echo "Wrote $out"
