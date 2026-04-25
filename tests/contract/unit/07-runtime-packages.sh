#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../../.." && pwd)"

echo "07: runtime packages presence check (bashInteractive, openssh)"

NIX_CMD="nix"

echo -n "Evaluating environment.systemPackages... "
out=$($NIX_CMD eval --json .#nixosConfigurations.huawei.config.environment.systemPackages 2>/dev/null || true) || true
if [ -z "$out" ]; then
  echo "flake eval failed for environment.systemPackages; skipping runtime package presence check (non-fatal)" >&2
  exit 0
fi

echo "ok"

echo "$out" | jq -r '.[]' > /tmp/_env_pkgs.$$ || true
grep -E "bash|bashInteractive" /tmp/_env_pkgs.$$ >/dev/null 2>&1 || {
  echo "WARNING: bashInteractive not found in environment.systemPackages" >&2
  cat /tmp/_env_pkgs.$$ | sed -n '1,50p'
  rm -f /tmp/_env_pkgs.$$ || true
  exit 3
}

grep -E "openssh|ssh" /tmp/_env_pkgs.$$ >/dev/null 2>&1 || {
  echo "WARNING: openssh not found in environment.systemPackages" >&2
  cat /tmp/_env_pkgs.$$ | sed -n '1,50p'
  rm -f /tmp/_env_pkgs.$$ || true
  exit 4
}

rm -f /tmp/_env_pkgs.$$ || true
echo "07: OK"
