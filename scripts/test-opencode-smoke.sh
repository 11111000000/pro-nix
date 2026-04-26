#!/usr/bin/env bash
set -euo pipefail

echo "[smoke] Check opencode is available"
if ! command -v opencode >/dev/null 2>&1; then
  echo "opencode not found on PATH" >&2
  exit 2
fi

echo "opencode --version:"
opencode --version

echo "opencode --help (short):"
opencode --help | head -n 10

echo "Run opencode --pure --version to ensure no plugin loading crashes"
opencode --pure --version

echo "Done: opencode smoke OK"
