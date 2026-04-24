#!/usr/bin/env bash
# Contract Proof header
# Surface: SystemRuntimePaths
# Stability: FLUID
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
set -- /nix/store/*-nix-*/bin/nix
if [ ! -x "${1:-}" ]; then
  echo "nix binary not found in /nix/store" >&2
  exit 2
fi
out="$("$1" build --no-link --print-out-paths "$root"#nixosConfigurations.huawei.config.system.build.toplevel)"

for tool in bash ssh; do
  if [ ! -x "$out/sw/bin/$tool" ]; then
    echo "missing runtime tool: $out/sw/bin/$tool" >&2
    exit 1
  fi
done

echo "contract: OK"
