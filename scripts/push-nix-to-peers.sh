#!/usr/bin/env bash
set -euo pipefail

# push-nix-to-peers.sh
# Usage: push-nix-to-peers.sh /nix/store/abcd... /nix/store/xyz...

PEERS_FILE="${HOME}/.local-peers"

if [ ! -f "$PEERS_FILE" ]; then
  echo "Peers file not found: $PEERS_FILE"
  echo "Create it with one peer per line, e.g. cf19.local" >&2
  exit 1
fi

if [ $# -lt 1 ]; then
  echo "Usage: $0 /nix/store/... [more paths]" >&2
  exit 1
fi

paths=("$@")

while IFS= read -r peer; do
  peer="$(echo "$peer" | sed -e 's/[[:space:]]*$//')"
  [ -z "$peer" ] && continue
  [ "${peer:0:1}" = "#" ] && continue
  echo "===> Trying peer: $peer"
  for p in "${paths[@]}"; do
    if [ ! -e "$p" ]; then
      echo "Path not found locally: $p" >&2
      continue
    fi
    echo "Copying $p -> $peer"
    if nix copy --to "ssh://$USER@$peer" "$p"; then
      echo "Copied $p -> $peer"
    else
      echo "Failed to copy $p -> $peer" >&2
    fi
  done
done < "$PEERS_FILE"

echo "Done."
