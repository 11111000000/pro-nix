#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../../.." && pwd)"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

# Proof requirement: gpg must be available for this dry-run smoke test.
if ! command -v gpg >/dev/null 2>&1; then
  echo "06: ERROR: 'gpg' is required for this test but not found in PATH" >&2
  exit 1
fi

echo "06: pro-peer sync script dry-run test"

# Create a dummy input file to simulate encrypted file (we won't actually decrypt)
inp="$tmpdir/authorized_keys.gpg"
printf 'dummy' > "$inp"

# Run script in dry-run mode; it should exit 0 and not write output
out="$tmpdir/out.auth"
bash "$root/scripts/ops-pro-peer-sync-keys.sh" --input "$inp" --out "$out" --dry-run

if [ -e "$out" ]; then
  echo "dry-run should not write output file" >&2
  exit 2
fi

echo "06: OK"
