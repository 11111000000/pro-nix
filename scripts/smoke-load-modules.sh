#!/usr/bin/env bash
set -euo pipefail

# Smoke-load each pro-*.el module in a fresh Emacs --batch -Q process.
# This avoids interactions between modules when loaded into the same session
# (useful for detecting syntax/parse/load errors in individual files).

ROOT=$(dirname "$(realpath "$0")")/..
MODDIR="$ROOT/emacs/base/modules"

failures=()
for f in "$MODDIR"/pro-*.el; do
  bn=$(basename "$f")
  echo "==> loading $bn"
  # Preload minimal pro helpers so modules can consult availability helpers
  preload=("pro-core.el" "pro-compat.el" "pro-packages.el" "pro-ui.el")
  args=("--batch" "-Q")
  for p in "${preload[@]}"; do
    if [ -f "$MODDIR/$p" ]; then
      args+=("-l" "$MODDIR/$p")
    fi
  done
  args+=("-l" "$f" "--eval" '(message "loaded")')
  if emacs "${args[@]}" >/dev/null 2>&1; then
    echo "OK $bn"
  else
    echo "FAIL $bn"
    failures+=("$bn")
  fi
done

if [ ${#failures[@]} -ne 0 ]; then
  echo "\nFailures:"; printf "  %s\n" "${failures[@]}"
  exit 2
fi

echo "All modules loaded OK (isolated runs)."
exit 0
