#!/usr/bin/env bash
# Contract Proof header
# Surface: Soft Reload (Emacs)
# Stability: FROZEN
# Invariant: INV-Surface-First
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"

# Support both legacy reload.el and current pro-reload.el; also accept any
# module file that contains the expected helpers (robust against renames).
files=("$root"/emacs/base/modules/*reload*.el)
modfile=""
if [ -f "${files[0]-}" ]; then
  modfile="${files[0]}"
fi

if [ -z "${modfile}" ]; then
  echo "reload helper missing: no *reload*.el in emacs/base/modules" >&2
  exit 2
fi

if ! rg -n "pro/reload-module|pro/reload-all-modules|pro/session-save-and-restart-emacs" "$modfile" >/dev/null 2>&1; then
  echo "soft reload helpers not documented in code (checked: $modfile)" >&2
  exit 2
fi

echo "soft reload contract: OK (checked: $modfile)"
