#!/usr/bin/env bash
set -euo pipefail
# Find and try to load each Emacs Lisp file under the user's config modules dir.
# Exit non-zero if any file fails to load in batch mode.

EMACS=${EMACS:-emacs}
MODULE_DIR=${MODULE_DIR:-$HOME/.config/emacs/modules}

if [ ! -x "$(command -v "$EMACS")" ]; then
  echo "emacs binary not found: $EMACS" >&2
  exit 2
fi

if [ ! -d "$MODULE_DIR" ]; then
  echo "Module directory not found: $MODULE_DIR" >&2
  exit 2
fi

# Behavior:
# - For each .el file in MODULE_DIR, first attempt to READ (parse) all top-level forms
#   using Emacs in batch mode. This detects syntax/read errors (unbalanced parens, invalid
#   read syntax) without executing user code.
# - Optionally attempt to byte-compile the file (set BYTE_COMPILE=1) which will run the
#   byte-compiler and may surface other issues.

BYTE_COMPILE=${BYTE_COMPILE:-0}

fail=0
for f in "$MODULE_DIR"/*.el; do
  [ -e "$f" ] || continue
  printf "Checking %s... " "$f"
  # 1) Read-only parse check: read all top-level forms without evaluating them.
  if "$EMACS" -Q --batch --eval "(progn (with-temp-buffer (insert-file-contents \"$f\") (goto-char (point-min)) (condition-case err (progn (while (< (point) (point-max)) (read (current-buffer))) (princ \"READ_OK\")) (error (princ (format \"READ_ERR: %s\" err))))) )" 2> /tmp/elisp-check-err; then
    out=$(cat /tmp/elisp-check-err)
    if printf "%s" "$out" | grep -q "READ_OK"; then
      echo -n "PARSE OK"
    else
      echo "PARSE FAIL"
      sed -n '1,200p' /tmp/elisp-check-err || true
      fail=1
      continue
    fi
  else
    echo "PARSE FAIL"
    sed -n '1,200p' /tmp/elisp-check-err || true
    fail=1
    continue
  fi

  # 2) Optional byte-compile check (may still succeed despite runtime missing deps).
  if [ "$BYTE_COMPILE" = "1" ]; then
    if "$EMACS" -Q --batch --eval "(progn (byte-compile-file \"$f\") (princ \"BC_OK\"))" 2> /tmp/elisp-check-err; then
      echo " | BYTE-COMPILE OK"
    else
      echo " | BYTE-COMPILE FAIL"
      sed -n '1,200p' /tmp/elisp-check-err || true
      fail=1
    fi
  else
    echo
  fi
done

rm -f /tmp/elisp-check-err
exit $fail
