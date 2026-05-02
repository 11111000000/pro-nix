#!/usr/bin/env bash
set -euo pipefail

# Thin wrapper for pro-peer-sync-keys.sh to normalize arguments when invoked
# from systemd units. Accepts two positional args: <input.gpg> <out-file>

INPUT=${1:-/etc/pro-peer/authorized_keys.gpg}
OUT=${2:-/var/lib/pro-peer/authorized_keys}

exec /run/current-system/sw/bin/bash /etc/pro-peer-sync-keys.sh --input "$INPUT" --out "$OUT" --dry-run
