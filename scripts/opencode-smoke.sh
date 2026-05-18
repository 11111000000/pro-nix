#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"

cd "$root"

echo "opencode smoke: checking HM module wiring"

# Verify the Home Manager opencode-bwrap module is enabled. We intentionally
# do not ship opencode plugin sources in the repository; the supported runtime
# is the bubblewrap-backed `programs.opencode-bwrap` module.
enabled="$(nix eval --json .#nixosConfigurations.huawei.config.home-manager.users.az.programs.opencode-bwrap.enable)"
if [ "$enabled" != "true" ]; then
  echo "programs.opencode-bwrap.enable is not true: $enabled" >&2
  exit 3
fi

packages="$(nix eval --json .#nixosConfigurations.huawei.config.home-manager.users.az.home.packages)"
if ! printf '%s' "$packages" | jq -e '.[] | select(test("opencode-bwrap"))' >/dev/null; then
  echo "opencode-bwrap is missing from home.packages" >&2
  exit 4
fi

echo "opencode smoke: OK"
