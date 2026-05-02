#!/usr/bin/env bash
set -euo pipefail

# Minimal helper to ensure /var/lib/tor ownership and modes for Tor
# This is intended to be called from a systemd oneshot unit.

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  echo "pro-peer-ensure-tor-perms: must be run as root" >&2
  exit 2
fi

if [ -d /var/lib/tor ]; then
  chown -R tor:tor /var/lib/tor || true
  chmod 700 /var/lib/tor || true
  if [ -d /var/lib/tor/ssh_hidden_service ]; then
    chmod 700 /var/lib/tor/ssh_hidden_service || true
  fi
fi

exit 0
