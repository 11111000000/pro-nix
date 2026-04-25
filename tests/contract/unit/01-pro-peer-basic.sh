#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../../.." && pwd)"

echo "01: pro-peer basic checks"

# This unit proof keeps the peer/security contract visible without requiring a
# full system activation in CI.

NIX="nix"

val=$($NIX eval --json .#nixosConfigurations.huawei.config.pro-peer 2>/dev/null || true)
if [ -z "$val" ]; then
  echo "failed to eval pro-peer config" >&2
  exit 2
fi

enable=$($NIX eval --json .#nixosConfigurations.huawei.config.pro-peer.enable 2>/dev/null || true)
if [ "$enable" != "true" ]; then
  echo "pro-peer.enable is not true: $enable" >&2
  exit 3
fi

enableKeySync=$($NIX eval --json .#nixosConfigurations.huawei.config.pro-peer.enableKeySync 2>/dev/null || true)
if [ "$enableKeySync" != "true" ]; then
  echo "pro-peer.enableKeySync is not true: $enableKeySync" >&2
  exit 4
fi

keySyncInterval=$($NIX eval --json .#nixosConfigurations.huawei.config.pro-peer.keySyncInterval 2>/dev/null || true)
if [ -z "$keySyncInterval" ] || [ "$keySyncInterval" = "null" ]; then
  echo "pro-peer.keySyncInterval missing" >&2
  exit 5
fi

echo "01: OK"
