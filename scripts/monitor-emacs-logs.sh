#!/usr/bin/env bash
set -euo pipefail

# Simple monitor that scans the latest headless run for actionable patterns
LOG_ROOT=${1:-${EMACS_HEADLESS_LOG_DIR:-$PWD/logs/emacs-headless}}
PATTERNS=("command .* not found for key" "ERROR" "FAILED")

latest=$(ls -1td "$LOG_ROOT"/*/ 2>/dev/null | head -n1 || true)
if [[ -z "$latest" ]]; then
  echo "No headless runs under $LOG_ROOT"
  exit 0
fi

echo "Monitoring logs in $latest"
for f in "$latest"/*.log "$latest"/*/*.log; do
  [[ -f "$f" ]] || continue
  for p in "${PATTERNS[@]}"; do
    if rg -n --hidden --no-messages -e "$p" "$f"; then
      echo "[ALERT] pattern '$p' found in $f"
    fi
  done
done

echo "Done"
