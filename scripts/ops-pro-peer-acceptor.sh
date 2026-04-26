#!/usr/bin/env bash
set -euo pipefail

# pro-peer-acceptor.sh
# Forced-command helper for restricted SSH keys. It validates the incoming
# environment and permits only a small set of allowed operations (like nix copy).

LOGFILE=/var/log/pro-peer-acceptor.log
exec >> "$LOGFILE" 2>&1

echo "[$(date -Iseconds)] pro-peer-acceptor invoked by $SSH_CONNECTION with key fingerprint $SSH_ORIGINAL_COMMAND"

# Basic validation: only allow a single command pattern (example: allow nix-copy)
if [[ -z "${SSH_ORIGINAL_COMMAND:-}" ]]; then
  echo "No command provided; rejecting."; exit 1
fi

cmd="$SSH_ORIGINAL_COMMAND"

# Allow only nix copy related operations (simple whitelist)
if [[ "$cmd" =~ ^nix[[:space:]]+copy.* ]] || [[ "$cmd" =~ ^nix-store.* ]] ; then
  echo "Permitted command: $cmd"
  # execute under a restricted shell
  /bin/sh -c "$cmd"
  exit $?
else
  echo "Rejected command: $cmd"; exit 2
fi
