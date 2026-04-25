#!/usr/bin/env bash
set -euo pipefail

# Проверка: модули, связанные с Tor, должны содержать сервисы/обеспечения прав
root="$(cd "$(dirname "$0")/../.." && pwd)"
f="$root/modules/pro-privacy.nix"
if [ ! -f "$f" ]; then
  echo "pro-privacy module not found: $f" >&2
  exit 2
fi

# Ищем упоминания tor-ensure-perms или /var/lib/tor
if rg -q 'tor-ensure-perms' "$f" 2>/dev/null || rg -q '/var/lib/tor' "$f" 2>/dev/null; then
  echo "pro-privacy: tor-related artifacts documented"
  exit 0
else
  echo "pro-privacy: missing tor artifacts (tor-ensure-perms or /var/lib/tor)" >&2
  exit 3
fi
