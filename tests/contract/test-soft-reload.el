#!/usr/bin/env bash
# Contract Proof header
# Surface: Soft Reload (Emacs)
# Stability: FROZEN
# Invariant: INV-Surface-First
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"

if [ ! -f "$root/emacs/base/modules/reload.el" ]; then
  echo "reload helper missing" >&2
  exit 2
fi

if ! rg -n "pro/reload-module|pro/reload-all-modules|pro/session-save-and-restart-emacs" "$root/emacs/base/modules/reload.el" >/dev/null 2>&1; then
  echo "soft reload helpers not documented in code" >&2
  exit 2
fi

echo "soft reload contract: OK"
