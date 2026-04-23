#!/usr/bin/env bash
# Produce a small elisp file with discovered Nix site-lisp paths.
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT_EL=$(realpath "$REPO_ROOT/emacs/base/nix-emacs-paths.el")

echo "Generating Nix Emacs site-lisp paths -> $OUT_EL"

# Find candidate site-lisp directories under /nix/store
paths=()
while IFS= read -r -d $'\0' d; do
  paths+=("$d")
done < <(find /nix/store -maxdepth 4 -type d -name site-lisp -print0 2>/dev/null || true)

# Deduplicate and sort
IFS=$'\n' sorted=($(printf "%s\n" "${paths[@]}" | sort -u))
unset IFS

mkdir -p "$(dirname "$OUT_EL")"
cat > "$OUT_EL" <<EOF
;; Auto-generated list of Nix-provided Emacs site-lisp dirs
(defvar pro/nix-site-lisp-paths
  '(
EOF
for p in "${sorted[@]}"; do
  echo "  \"$p\"" >> "$OUT_EL"
done
cat >> "$OUT_EL" <<'EOF'
  )
  "List of site-lisp directories discovered in /nix/store.")

(provide 'nix-emacs-paths)
EOF

echo "Wrote $OUT_EL"
