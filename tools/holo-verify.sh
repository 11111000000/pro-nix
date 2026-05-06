#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
echo "Running holo verification from $root"

run_elisp_checks() {
  if [ -x "$root/scripts/helper-check-elisp.sh" ]; then
    echo "Running Emacs Lisp parse checks for repo modules..."
    EMACS="$root/scripts/dev-emacs-pro-wrapper.sh" MODULE_DIR="$root/emacs/base/modules" \
      bash "$root/scripts/helper-check-elisp.sh" || { echo "helper-check-elisp failed"; exit 4; }
  fi

  if [ -d "$HOME/.config/emacs/modules" ]; then
    echo "Running Emacs Lisp parse checks for user modules in $HOME/.config/emacs/modules..."
    EMACS="$root/scripts/dev-emacs-pro-wrapper.sh" MODULE_DIR="$HOME/.config/emacs/modules" \
      bash "$root/scripts/helper-check-elisp.sh" || { echo "helper-check-elisp (user) failed"; exit 5; }
  fi
}

shopt -s nullglob
MODE=${1:-unit}

case "$MODE" in
  quick|--quick) MODE=unit ;;
  elisp|--elisp) MODE=elisp ;;
  nixos-fast|--nixos-fast) ;;
  all|--all|full|--full) ;;
  unit) ;;
  *) echo "Unknown mode: $MODE" >&2; exit 1 ;;
esac

if [ "$MODE" = "elisp" ]; then
  run_elisp_checks
  echo "holo-verify: OK"
  exit 0
fi

if [ "$MODE" = "unit" ]; then
  pattern="$root/tests/contract/unit/*"
elif [ "$MODE" = "nixos-fast" ]; then
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
