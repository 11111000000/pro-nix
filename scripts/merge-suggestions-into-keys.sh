#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(dirname "$0")/..
REPO_ROOT=$(cd "$REPO_ROOT" && pwd)
OUT_TMP=$(mktemp -t emacs-keys-suggestions.XXXXXX)

echo "Generating suggestions via Emacs... -> $OUT_TMP"
# Use the emacs-pro-wrapper to ensure same -L flags as CI/dev
"$REPO_ROOT/scripts/emacs-pro-wrapper.sh" --batch -l emacs/base/init.el --eval "(pro/keys-import-suggestions \"$OUT_TMP\")"

if [ ! -s "$OUT_TMP" ]; then
  echo "No suggestions generated or file empty: $OUT_TMP"
  exit 1
fi

KEYS_FILE="$REPO_ROOT/emacs-keys.org"
BACKUP="$KEYS_FILE.bak.$(date +%Y%m%d%H%M%S)"
cp "$KEYS_FILE" "$BACKUP"
echo "Backed up $KEYS_FILE -> $BACKUP"

echo "Merging suggested keys into $KEYS_FILE"

TMP_NEW=$(mktemp -t emacs-keys-new.XXXXXX)
cp "$KEYS_FILE" "$TMP_NEW"

# Extract suggestion rows: lines that start with "| Suggested |"
grep '^| Suggested |' "$OUT_TMP" | while IFS= read -r line; do
  # extract key and command fields (2nd and 3rd columns)
  # format: | Suggested | <key> | <cmd> | ... |
  key=$(echo "$line" | awk -F"|" '{gsub(/^[ \t]+|[ \t]+$/,"",$3); print $3}')
  cmd=$(echo "$line" | awk -F"|" '{gsub(/^[ \t]+|[ \t]+$/,"",$4); print $4}')
  # check if a row with same key and cmd exists in current keys file
  if grep -q "|[[:space:]]*.*[[:space:]]|[[:space:]]*$key[[:space:]]|[[:space:]]*$cmd[[:space:]]|" "$KEYS_FILE"; then
    echo "Skipping existing: $key -> $cmd"
  else
    echo "Adding: $key -> $cmd"
    # append a provenance header and the row to the end of file
    echo "" >> "$TMP_NEW"
    echo "# AUTO-MERGED: $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$TMP_NEW"
    echo "$line" >> "$TMP_NEW"
  fi
done

mv "$TMP_NEW" "$KEYS_FILE"
echo "Wrote merged keys to $KEYS_FILE"

# Commit changes
cd "$REPO_ROOT"
git add "$KEYS_FILE"
git commit -m "chore(keys): auto-merge module suggestions into emacs-keys.org" || echo "No changes to commit"

echo "Done. If you want to review changes, see git diff $BACKUP $KEYS_FILE"
