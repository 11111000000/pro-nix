#!/usr/bin/env bash
set -euo pipefail

# Thin wrapper for pro-samba-sync-keys.sh to be invoked reliably from systemd.
# Accepts --input and --out flags and forwards them to the real script path.

exec /run/current-system/sw/bin/bash /etc/pro-samba-sync-keys.sh "$@"
