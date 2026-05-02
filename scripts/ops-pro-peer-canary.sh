#!/usr/bin/env bash
set -euo pipefail

# Lightweight canary wrapper for pro-peer key sync.
# Usage: scripts/ops-pro-peer-canary.sh --input /path/to/authorized_keys.gpg --out /var/lib/pro-peer/authorized_keys
# This will run the sync script in --dry-run mode and print expected actions.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/scripts/ops-pro-peer-sync-keys.sh"

usage() {
  cat <<EOF
Usage: $0 --input /path/to/authorized_keys.gpg --out /var/lib/pro-peer/authorized_keys

This runs the pro-peer sync in dry-run mode and shows what would be done.
Operator should inspect output, backups and only then run the real script on a canary host.
EOF
}

INPUT=""
OUT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --input) INPUT="$2"; shift 2;;
    --out) OUT="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1"; usage; exit 2;;
  esac
done

if [ -z "$INPUT" ] || [ -z "$OUT" ]; then
  usage; exit 2
fi

echo "Running canary dry-run for pro-peer key sync"
echo "Input: $INPUT"
echo "Out: $OUT"

if [ ! -x "$SCRIPT" ]; then
  echo "sync script not found or not executable: $SCRIPT" >&2
  exit 2
fi

echo "-> Executing: $SCRIPT --input $INPUT --out $OUT --dry-run"
set -x
"$SCRIPT" --input "$INPUT" --out "$OUT" --dry-run
set +x

echo "Canary dry-run complete. If output indicates desired changes, run the same command without --dry-run on the canary host to apply." 
