#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../../.." && pwd)"

echo "01: pro-peer basic checks"

# This unit proof keeps the peer/security contract visible without requiring a
# full system activation in CI.

NIX="nix --no-write-lock-file --impure"

f="$root/modules/pro-peer.nix"
if [ ! -f "$f" ]; then
  echo "pro-peer module not found: $f" >&2
  exit 2
fi

echo -n "Checking pro-peer options in $f... "
ok=0
rg -n "enableKeySync" "$f" >/dev/null 2>&1 && ok=$((ok+1))
rg -n "keySyncInterval" "$f" >/dev/null 2>&1 && ok=$((ok+1))
rg -n "keysGpgPath" "$f" >/dev/null 2>&1 && ok=$((ok+1))

if [ "$ok" -lt 3 ]; then
  echo "MISSING options in pro-peer module (found $ok/3)" >&2
  rg -n "enableKeySync|keySyncInterval|keysGpgPath" "$f" || true
  exit 3
fi

echo "OK"
