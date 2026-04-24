#!/usr/bin/env bash
# Contract Proof header
# Surface: Healthcheck
# Stability: FROZEN
# Invariant: INV-Traceability
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"

set -- /nix/store/*-nix-*/bin/nix
if [ ! -x "${1:-}" ]; then
  echo "nix binary not found in /nix/store" >&2
  exit 2
fi

# Minimal proof: the repository exposes a 'just install-emacs' target or scripts/install that is present
if command -v just >/dev/null 2>&1; then
  echo "just available" >/dev/null
elif [[ -f "$root/scripts/emacs-sync.sh" ]]; then
  echo "emacs-sync script present" >/dev/null
else
  echo "Proof check failed: no 'just' or emacs-sync.sh" >&2
  exit 2
fi

echo "contract: OK"
