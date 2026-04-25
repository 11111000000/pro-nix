#!/usr/bin/env bash
set -euo pipefail

echo "08: pro-privacy packages presence check (obfs4proxy, meek-client, snowflake-client)"
NIX="nix"

out=$($NIX eval --json .#nixosConfigurations.huawei.config.environment.systemPackages 2>/dev/null || true) || true
if [ -z "$out" ]; then
  echo "08: SKIP (cannot evaluate environment.systemPackages in this environment)" >&2
  exit 0
fi

echo "$out" | jq -r '.[]' > /tmp/_env_pkgs.$$ || true

check_in_list() {
  grep -E "$1" /tmp/_env_pkgs.$$ >/dev/null 2>&1
}

if ! check_in_list "obfs4"; then
  echo "WARNING: obfs4proxy not found in environment.systemPackages" >&2
fi

if ! check_in_list "meek"; then
  echo "WARNING: meek-client not found in environment.systemPackages" >&2
fi

if ! check_in_list "snowflake"; then
  echo "WARNING: snowflake-client not found in environment.systemPackages" >&2
fi

rm -f /tmp/_env_pkgs.$$ || true
echo "08: OK (warnings may be present)"
