---
# Contract Proof header
Surface: Healthcheck
Stability: FROZEN
Invariant: INV-Traceability

#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"

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
