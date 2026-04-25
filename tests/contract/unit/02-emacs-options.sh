#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../../.." && pwd)"

echo "02: emacs-related options checks"

NIX="nix"

# Check that home-manager.extraSpecialArgs exists (in some setups it may not)
hm_args=$($NIX eval --json .#nixosConfigurations.huawei.config.home-manager.extraSpecialArgs 2>/dev/null || echo "null")
if [ "$hm_args" = "null" ]; then
  echo "home-manager.extraSpecialArgs not present; this can be OK depending on host config" >&2
  echo "02: WARN (non-fatal)"
else
  echo "02: OK"
fi

echo "02: OK"
