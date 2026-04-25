#!/usr/bin/env bash
set -euo pipefail

# Простая контрактная проверка для pro-peer: ожидаем, что модуль упоминает
# runtime-файл /var/lib/pro-peer/authorized_keys или определяет tmpfiles правило.
root="$(cd "$(dirname "$0")/../.." && pwd)"
f="$root/modules/pro-peer.nix"
if [ ! -f "$f" ]; then
  echo "pro-peer module not found: $f" >&2
  exit 2
fi

if rg -q '/var/lib/pro-peer/authorized_keys' "$f" 2>/dev/null || rg -q 'pro-peer.*authorized_keys' "$f" 2>/dev/null; then
  echo "pro-peer: authorized_keys mentioned in module"
  exit 0
else
  echo "pro-peer: authorized_keys not documented in module" >&2
  exit 3
fi
