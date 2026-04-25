#!/usr/bin/env bash
set -euo pipefail

echo "05: mkForce lint smoke test"
./tools/mkforce-lint.sh
echo "05: OK"
