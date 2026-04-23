#!/usr/bin/env bash
set -euo pipefail

# Fail if any module (outside keys.el) sets global keys at top level.
violations=$(rg -n "\\bglobal-set-key\\s*\\(" --glob "**/*.el" | grep -v "/keys.el:") || true
if [ -n "$violations" ]; then
  echo "[lint-keys] Disallowed global-set-key usage found:" >&2
  echo "$violations" >&2
  exit 1
fi

echo "[lint-keys] OK: no disallowed global-set-key in modules"
