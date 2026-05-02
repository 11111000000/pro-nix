#!/usr/bin/env bash
set -euo pipefail
# Compatibility helper: a trimmed report script used by system activation
REPORT_DATE="$(date)"
HOSTNAME="$(hostname)"
USER="$(whoami)"
EMACS_VER="$(command -v emacs >/dev/null 2>&1 && emacs --version | head -1 || echo 'emacs-not-found')"
echo "Emacs headless report: $REPORT_DATE"
echo "Hostname: $HOSTNAME"
echo "User: $USER"
echo "Emacs version: $EMACS_VER"
echo "Report script present"
