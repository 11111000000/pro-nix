#!/usr/bin/env bash
set -euo pipefail

# Simple PR body Change Gate checker. Expects PR body in env var PR_BODY or reads from stdin.
BODY="${PR_BODY:-$(cat || true)}"

if echo "$BODY" | rg -q "Intent:" && echo "$BODY" | rg -q "Pressure:" && echo "$BODY" | rg -q "Surface"; then
  echo "Change Gate block present"
  exit 0
else
  echo "Change Gate block missing or incomplete. Please add Intent/Pressure/Surface/Proof in PR description." >&2
  # Non-zero exit would block PR; we return 78 to allow non-blocking commentary behavior in initial rollout.
  exit 78
fi
