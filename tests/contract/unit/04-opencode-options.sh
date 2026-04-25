#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../../.." && pwd)"
NIX="nix"

echo "04: opencode options checks"

val=$($NIX eval --json .#nixosConfigurations.huawei.config.provisioning.opencode.enable 2>/dev/null || true)
if [ "$val" != "true" ]; then
  echo "provisioning.opencode.enable is not true or not configured for this host: $val" >&2
  echo "04: SKIP (not enabled)"
  exit 0
fi

tmpl=$($NIX eval --raw .#nixosConfigurations.huawei.config.provisioning.opencode.userTemplate 2>/dev/null || true)
if [ -z "$tmpl" ]; then
  echo "provisioning.opencode.userTemplate missing" >&2
  exit 3
fi

echo "04: OK"
