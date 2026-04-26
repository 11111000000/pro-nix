#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../../.." && pwd)"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

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
