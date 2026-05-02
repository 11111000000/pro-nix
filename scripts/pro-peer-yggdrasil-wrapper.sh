#!/usr/bin/env bash
set -euo pipefail

# Wrapper to launch yggdrasil with a predictable path and config file.
CFG=${1:-/etc/yggdrasil.conf}
exec /run/current-system/sw/bin/yggdrasil -useconffile "$CFG"
