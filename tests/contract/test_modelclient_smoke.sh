#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
echo "model-client smoke: verify app entrypoint exists"

if [ ! -f "$root/apps/model-client/app.py" ]; then
  echo "model-client app missing" >&2
  exit 2
fi

echo "model-client smoke: OK"
