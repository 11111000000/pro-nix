#!/usr/bin/env bash
set -euo pipefail

# Исправляет require/featurep/with-eval-after-load на pro- версии и удаляет
# небезопасные provide'ы без префикса pro- в emacs/base/modules.

ROOT=$(dirname "$(realpath "$0")")/..
MODULES_DIR="$ROOT/emacs/base/modules"
echo "Module dir: $MODULES_DIR"

cd "$ROOT"

# collect bases from pro-*.el filenames
bases=()
while IFS= read -r f; do
  name=$(basename "$f" .el)
  # remove leading pro-
  base=${name#pro-}
  bases+=("$base")
done < <(printf "%s\n" "$MODULES_DIR"/pro-*.el 2>/dev/null)

for b in "${bases[@]}"; do
  echo "Patching references to '$b' -> 'pro-$b'..."
  # find files referencing require/featurep/with-eval-after-load 'b within repo
  rg --hidden --no-ignore -S "(require\s+'${b}\b|featurep\s+'${b}\b|with-eval-after-load\s+'${b}\b)" -g '!emacs/base/modules/legacy-removed/**' -n || true
  # Replace only inside emacs/base/modules and other .el files under emacs
  rg --hidden --no-ignore -S "(require\s+'${b}\b|featurep\s+'${b}\b|with-eval-after-load\s+'${b}\b)" -n emacs || true | cut -d: -f1 | sort -u | while IFS= read -r file; do
    echo "  updating $file"
    # use perl to replace three patterns
    perl -0777 -pe "s/\(require\s+'${b}\\b/\(require 'pro-${b}/g; s/\(featurep\s+'${b}\\b/\(featurep 'pro-${b}/g; s/\(with-eval-after-load\s+'${b}\\b/\(with-eval-after-load 'pro-${b}/g;" -i "$file"
  done
done

echo "Removing non-pro provide forms under $MODULES_DIR..."
# For each .el under modules, remove provide lines whose symbol doesn't start with pro-
find "$MODULES_DIR" -type f -name "*.el" ! -path "*/legacy-removed/*" -print0 | while IFS= read -r -d '' f; do
  # remove lines like: (provide 'foo)
  perl -0777 -pe "s/^\s*\(provide\s+'(?!pro-)[A-Za-z0-9_:-]+\)\s*\n//mg" -i "$f"
  echo "  cleaned $f"
done

echo "Ensuring each pro-*.el has corresponding (provide 'pro-name)"
for f in "$MODULES_DIR"/pro-*.el; do
  [ -e "$f" ] || continue
  name=$(basename "$f" .el)
  if ! rg -n "\(provide\s+'${name}\)" -q "$f" 2>/dev/null; then
    echo "  adding provide to $f"
    printf "\n(provide '%s)\n" "$name" >> "$f"
  fi
done

git add -A
git commit -m "emacs: normalize provides to pro-*; update requires to pro-* where modules exist" || true

echo Done
