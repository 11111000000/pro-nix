#!/usr/bin/env bash
set -euo pipefail

LOG_DIR="${1:-logs/emacs-headless}"
LATEST_DIR="$(ls -1dt "$LOG_DIR"/* 2>/dev/null | head -n 1 || true)"
if [[ -z "$LATEST_DIR" ]]; then
  echo "No headless logs found in $LOG_DIR" >&2
  exit 1
fi

echo "Latest run: $LATEST_DIR"
for f in run.log tty.log xorg.log; do
  if [[ -f "$LATEST_DIR/$f" ]]; then
    echo
    echo "== $f =="
    tail -n 40 "$LATEST_DIR/$f"
  fi
done
