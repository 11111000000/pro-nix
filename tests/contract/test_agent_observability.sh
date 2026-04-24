#!/usr/bin/env bash
# Contract Proof header
# Surface: Agent Observability
# Stability: FLUID
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"

if [ ! -f "$root/docs/SURFACE.md" ]; then
  echo "docs/SURFACE.md missing" >&2
  exit 2
fi

if ! rg -n "readiness|health|structured logs|health/readiness" "$root/docs/SURFACE.md" "$root/docs/plans/agent-orchestration.md" >/dev/null 2>&1; then
  echo "observability contract text missing" >&2
  exit 2
fi

echo "agent observability contract: OK"
