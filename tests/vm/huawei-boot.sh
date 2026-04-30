#!/usr/bin/env bash
set -euo pipefail

export NIXPKGS_ALLOW_UNFREE=1
exec nix build --impure 'path:/home/az/pro-nix#checks.x86_64-linux.huawei-boot'
