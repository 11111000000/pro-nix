#!/usr/bin/env bash
set -euo pipefail

# Thin wrapper to call the repo-provided backup-hiddenservice.sh with normalized
# argument quoting and predictable behavior when invoked from systemd.

HIDDENDIR="${1:-/var/lib/tor/ssh_hidden_service}"
RECIP="${2:-}"
OUTDIR="${3:-/var/lib/pro-peer}"

if [ -z "$RECIP" ]; then
  echo "pro-peer-backup-hiddenservice: missing GPG recipient" >&2
  exit 2
fi

exec /run/current-system/sw/bin/bash /etc/pro-peer-backup-hiddenservice.sh --hidden-dir "$HIDDENDIR" --recipient "$RECIP" --out-dir "$OUTDIR"
