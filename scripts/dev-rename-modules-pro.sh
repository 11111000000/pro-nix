#!/usr/bin/env bash
set -euo pipefail

# Скрипт массового переименования Emacs-модулей в префикс pro-
#  - выполняет git mv для сохранения истории
#  - правит внутри файлов шапку и provide
#  - правит вызовы require/featurep/with-eval-after-load для переименованных фич
#
# Использование: ./scripts/rename-modules-pro.sh

ROOT=$(dirname "$(realpath "$0")")/..
MODULES_DIR="$ROOT/emacs/base/modules"

echo "Modules dir: $MODULES_DIR"

cd "$ROOT"

# Build list of .el files that do not start with pro-
mapfile -t files < <(find "$MODULES_DIR" -maxdepth 1 -type f -name "*.el" -printf "%f\n" | sort)

declare -a to_rename=()
for f in "${files[@]}"; do
  base="$f"
  if [[ "$base" == pro-*.el ]]; then
    continue
  fi
  # skip README and other non-module files if any
  case "$base" in
    README.md|provided-packages.el) continue;;
  esac
  to_rename+=("$base")
done

if [ ${#to_rename[@]} -eq 0 ]; then
  echo "No modules to rename."
  exit 0
fi

echo "Will rename the following modules:" 
printf "  %s\n" "${to_rename[@]}"

read -p "Proceed? [y/N] " ans
if [[ "$ans" != "y" && "$ans" != "Y" ]]; then
  echo "Aborted"
  exit 1
fi

for f in "${to_rename[@]}"; do
  name="${f%.el}"
  newname="pro-${name}.el"
  src="$MODULES_DIR/$f"
  dst="$MODULES_DIR/$newname"
  echo "Renaming $f -> $newname"
  if [ -e "$dst" ]; then
    echo "  Destination $newname already exists. Moving legacy file to legacy-removed/ for manual merge."
    mkdir -p "$MODULES_DIR/legacy-removed"
    git mv "$src" "$MODULES_DIR/legacy-removed/$f"
    dst="$MODULES_DIR/legacy-removed/$f"
  else
    git mv "$src" "$dst"
  fi

  # Update first header line: replace filename portion after ';;;' to pro-<name>.el
  perl -0777 -pe "s/^;;;\s+\Q$f\E\b/;;; $newname/" -i "$dst"

  # Update any trailing 'ends here' footer
  perl -0777 -pe "s/;;;\s+\Q$f\E\s+ends here/;;; $newname ends here/gi" -i "$dst"

  # Replace (provide 'name) -> (provide 'pro-name)
  # Replace (provide 'name) -> (provide 'pro-name)
  perl -0777 -pe "s/\(provide\s+'\Q${name}\E\)/\(provide 'pro-${name}\)/g" -i "$dst"

  # If file already provides pro-name and also old provide remains, remove old provide
  perl -0777 -pe "s/\(provide\s+'\Q${name}\E\)\s*\n//g" -i "$dst" || true

  # Replace common require/featurep/with-eval-after-load occurrences in modules
  # We only patch files under emacs/base/modules to limit impact.
  matches=$(rg -n --hidden --no-ignore -S "(require '${name}\b|featurep '${name}\b|with-eval-after-load '${name}\b)" "$MODULES_DIR" || true)
  if [ -n "$matches" ]; then
    echo "  patching references in modules..."
    while IFS= read -r m; do
      file=$(echo "$m" | cut -d: -f1)
      # Use perl for robust in-place replacement with word boundaries
      perl -0777 -pe "s/\(require\s+'${name}\b/\(require 'pro-${name}/g; s/\(featurep\s+'${name}\b/\(featurep 'pro-${name}/g; s/\(with-eval-after-load\s+'${name}\b/\(with-eval-after-load 'pro-${name}/g;" -i "$file"
    done <<< "$matches"
  fi

done

echo "Renames completed. Running git status..."
git status --porcelain

echo "You should run tests / emacs --batch loading to ensure nothing broke."
