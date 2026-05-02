#!/usr/bin/env bash
# Compatibility wrapper for legacy callers that expect scripts/switch.sh
set -euo pipefail
exec "$(dirname "$0")/helper-switch.sh" "$@"
