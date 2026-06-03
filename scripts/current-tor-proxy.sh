#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

gw=$(ip -4 route show default 2>/dev/null | awk '/default/ {print $3; exit}')
if [ -z "${gw:-}" ]; then
  echo "no default gateway" >&2
  exit 1
fi

for port in 9050 9150 8118; do
  if (exec 3<>/dev/tcp/"$gw"/"$port") 2>/dev/null; then
    exec 3>&- 3<&- || true
    printf '%s:%s\n' "$gw" "$port"
    exit 0
  fi
done

echo "no Tor proxy on gateway $gw (tried 9050 9150 8118)" >&2
exit 1
