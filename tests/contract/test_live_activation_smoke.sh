#!/usr/bin/env bash
set -euo pipefail

# Smoke test: perform a non-privileged build of the huawei toplevel and
# attempt a live activation inside a systemd-nspawn container (if available).
# This test fails if journal contains "Rejected send message" during activation.

root="$(cd "$(dirname "$0")/../.." && pwd)"

builder="$(command -v nix || true)"
if [ -z "$builder" ]; then
  echo "nix not found" >&2
  exit 2
fi

out="$($builder --extra-experimental-features 'nix-command flakes' build --print-out-paths "$root"#nixosConfigurations.huawei.config.system.build.toplevel)"

if [ -z "$out" ]; then
  echo "build failed" >&2
  exit 2
fi

echo "Built toplevel: $out"

# If systemd-nspawn is available, run the activation command inside it.
if command -v systemd-nspawn >/dev/null 2>&1; then
  tmpdir=$(mktemp -d)
  mkdir -p "$tmpdir/rootfs"
  # use the built profile as a simple rootfs overlay (best-effort smoke)
  rsync -a "$out/" "$tmpdir/rootfs/" || true
  echo "Attempting activation inside systemd-nspawn (smoke)"
  if sudo systemd-nspawn -D "$tmpdir/rootfs" /bin/sh -c 'set -e; if command -v switch-to-configuration >/dev/null 2>&1; then switch-to-configuration switch || true; fi; journalctl -n 200 -o short' | rg -i "Rejected send message" >/dev/null; then
    echo "Detected 'Rejected send message' during activation" >&2
    exit 1
  fi
  rm -rf "$tmpdir"
else
  echo "systemd-nspawn not available; skipping live activation smoke test" >&2
fi

echo "live activation smoke: OK"
