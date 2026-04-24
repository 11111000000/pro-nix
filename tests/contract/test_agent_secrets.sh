#!/usr/bin/env bash
# Contract Proof header
# Surface: Agent Secrets
# Stability: FROZEN
# Invariant: INV-Traceability
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"

tracked_secret_files="$(git -C "$root" ls-files -- \
  '*.env' '*.key' '*.pem' '*.p12' '*.pfx' '*.age' '*.gpg' \
  'credentials.json' 'credentials.yaml' 'credentials.yml' 'id_rsa' 'id_ed25519' 2>/dev/null || true)"
if [ -n "$tracked_secret_files" ]; then
  echo "tracked secret-like files detected:" >&2
  printf '%s\n' "$tracked_secret_files" >&2
  exit 2
fi

if [ ! -f "$root/docs/SURFACE.md" ] || [ ! -f "$root/docs/HOLO.md" ]; then
  echo "scoped agent docs missing" >&2
  exit 2
fi

echo "agent secrets contract: OK"
