#!/usr/bin/env bash
set -euo pipefail

# nix-build-and-share.sh
# Usage: nix-build-and-share.sh <nix-build-args...>
# Runs nix build, collects resulting store paths, and pushes them to peers.

BUILD_OUT=$(mktemp -d)
trap 'rm -rf "$BUILD_OUT"' EXIT

echo "Running nix build: $*"
nix build "$@" --out-link "$BUILD_OUT/result" || { echo "nix build failed"; exit 1; }

# Collect store paths from result
paths=( )
if [ -L "$BUILD_OUT/result" ]; then
  target=$(readlink -f "$BUILD_OUT/result")
  # gather store paths under result
  while IFS= read -r p; do
    paths+=("$p")
  done < <(nix-store --query --requisites "$target" | grep "/nix/store/")
fi

if [ ${#paths[@]} -eq 0 ]; then
  echo "No store paths found to share.";
  exit 0;
fi

echo "Sharing ${#paths[@]} paths to peers..."
exec "$(dirname "$0")/push-nix-to-peers.sh" "${paths[@]}"
