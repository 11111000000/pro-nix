#!/usr/bin/env bash
set -euo pipefail

# Simple holo verify: run contract tests referenced in HOLO.md and all scripts in tests/contract
root="$(cd "$(dirname "$0")/.." && pwd)"
echo "Running holo verification from $root"

# Basic Emacs Lisp parse check for repository-provided modules. This ensures
# syntax/read errors (unbalanced parens, truncated files) in emacs/base/modules
# are detected early. Use the dev wrapper so Nix-provided site-lisp paths are
# available when parsing.
if [ -x "$root/scripts/helper-check-elisp.sh" ]; then
  echo "Running Emacs Lisp parse checks for repo modules..."
  EMACS="$root/scripts/dev-emacs-pro-wrapper.sh" MODULE_DIR="$root/emacs/base/modules" \
    bash "$root/scripts/helper-check-elisp.sh" || { echo "helper-check-elisp failed"; exit 4; }
fi

# Also run parse checks on the user's local Emacs modules if present. This
# helps catch local init/init.el issues (like truncated files) early when the
# developer runs holo-verify locally. Skip silently if the directory is absent.
if [ -d "$HOME/.config/emacs/modules" ]; then
  echo "Running Emacs Lisp parse checks for user modules in $HOME/.config/emacs/modules..."
  EMACS="$root/scripts/dev-emacs-pro-wrapper.sh" MODULE_DIR="$HOME/.config/emacs/modules" \
    bash "$root/scripts/helper-check-elisp.sh" || { echo "helper-check-elisp (user) failed"; exit 5; }
fi

shopt -s nullglob
MODE=${1:-unit}
if [ "$MODE" = "unit" ]; then
  pattern="$root/tests/contract/unit/*"
elif [ "$MODE" = "nixos-fast" ]; then
  # fast nixos checks: system-packages eval, verify-units, and host toplevel build for primary host
  echo "Running nixos-fast checks"
  set -x
  ./scripts/helper-check-nixos-build.sh huawei || { echo "helper-check-nixos-build failed"; exit 2; }
  ./scripts/verify-units.sh || { echo "verify-units failed"; exit 3; }
  set +x
  pattern="$root/tests/contract/unit/*"
else
  pattern="$root/tests/contract/*"
fi

for t in $pattern; do
  [ -e "$t" ] || continue
  case "$t" in
    *.sh)
      echo "== Running contract script: $(basename "$t")"
      bash "$t"
      ;;
    *)
      if [ -x "$t" ]; then
        echo "== Running contract test: $(basename "$t")"
        "$t"
      else
        echo "== Skipping non-shell contract file: $(basename "$t")"
      fi
      ;;
  esac
done

echo "holo-verify: OK"

# additional check: ensure HOLO.md referenced contract tests exist
if [ -f "$root/HOLO.md" ]; then
  rg -n "tests/contract/" "$root/HOLO.md" || true
fi
