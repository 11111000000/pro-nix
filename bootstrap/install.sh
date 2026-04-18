#!/usr/bin/env bash
set -euo pipefail

host_profile="$("$(dirname "$0")/choose-host.sh")"
exec "$(dirname "$0")/install-pro.sh" "$host_profile"
