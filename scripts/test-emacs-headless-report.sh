#!/usr/bin/env bash
set -euo pipefail

# Отчет о работе emacs headless
REPORT_DATE="$(date)"
HOSTNAME="$(hostname)"
USER="$(whoami)"
EMACS_VER="$(emacs --version | head -1)"
echo "Emacs headless report: $REPORT_DATE"
echo "Hostname: $HOSTNAME"
echo "User: $USER"
echo "Emacs version: $EMACS_VER"

LOG_DIR="${1:-logs/emacs-headless}"
if [[ -d "$LOG_DIR" ]]; then
  LATEST="$(ls -1td "$LOG_DIR"/*/ 2>/dev/null | head -1)"
  if [[ -n "$LATEST" ]]; then
    echo ""
    echo "Latest run: $LATEST"
    if [[ -f "$LATEST/run.log" ]]; then
      echo "--- Summary ---"
      grep -E '\[pro-emacs\]|ERROR|error|FAIL|PASS|skipped' "$LATEST/run.log" 2>/dev/null | tail -30 || true
    fi
  fi
fi
echo "Report completed successfully"