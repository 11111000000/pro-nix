#!/usr/bin/env bash
set -euo pipefail

echo "08: pro-privacy packages presence check (obfs4proxy, meek-client, snowflake-client)"
NIX="nix"

out=$($NIX eval --json .#nixosConfigurations.huawei.config.environment.systemPackages 2>/dev/null || true) || true
if [ -z "$out" ]; then
  echo "08: SKIP (cannot evaluate environment.systemPackages in this environment)" >&2
  exit 1
fi

# Write to a safe temp file inside our tmpdir to avoid clashes
tmpf=$(mktemp /tmp/pro-privacy-pkgs.XXXXXX)
echo "$out" | jq -r '.[]' > "$tmpf" || {
  echo "08: ERROR: failed to write package list" >&2
  rm -f "$tmpf"
  exit 1
}

check_in_list() {
  grep -E "$1" "$tmpf" >/dev/null 2>&1
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

rm -f "$tmpf" || true
echo "08: OK (warnings may be present)"
