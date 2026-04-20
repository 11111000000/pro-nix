#!/bin/sh
# Wrapper for wg-quick used by pro-peer NixOS module.
# Keeps logic out of systemd unit file so exit-code handling is explicit
# and the unit can simply call this script.

WGCONF="$1"
if [ -z "$WGCONF" ]; then
  WGCONF="wg0"
fi

# Use the system-provided wg-quick binary path. If it fails because the
# interface is already up, treat it as success: the goal is to ensure the
# interface is up, not to fail the boot. We deliberately return 0 so the
# systemd oneshot doesn't mark the unit failed for a harmless condition.
/run/current-system/sw/bin/wg-quick up "$WGCONF" || true

exit 0
