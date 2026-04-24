#!/usr/bin/env bash
# Contract Proof header
# Surface: Soft Reload (Emacs)
# Stability: FROZEN
# Invariant: INV-Surface-First
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"

if [ ! -f "$root/tests/gui/gui-smoke.el" ]; then
  echo "gui smoke script missing" >&2
  exit 2
fi

if [ ! -f "$root/HOLO.md" ] || ! rg -n "test-gui-smoke\.el" "$root/HOLO.md" >/dev/null 2>&1; then
  echo "root HOLO does not reference the GUI smoke proof" >&2
  exit 2
fi

echo "gui smoke contract: OK"
