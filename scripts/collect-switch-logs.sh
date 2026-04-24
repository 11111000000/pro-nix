#!/usr/bin/env bash
set -euo pipefail

# Collect system logs and status useful for diagnosing a failed `nixos-rebuild switch`.
# Usage: ./scripts/collect-switch-logs.sh [OUTDIR]
# If run as non-root the script will attempt to use sudo where possible; if sudo
# cannot gain privileges it will still collect what it can and warn.

OUTBASE=${1:-./logs}
TS=$(date -u +%Y%m%dT%H%M%SZ)
OUTDIR="$OUTBASE/switch-logs-$TS"
mkdir -p "$OUTDIR"

echo "Collecting logs into: $OUTDIR"

SUDO=""
if sudo -n true 2>/dev/null; then
  SUDO=sudo
else
  echo "WARNING: sudo -n true failed; attempting to collect without root."
  echo "If you want full logs, re-run this script under an account that can sudo non-interactively, or run: sudo ./scripts/collect-switch-logs.sh" >&2
fi

run() {
  local f="$1"; shift
  echo "- $*" >"$OUTDIR/$f.log"
  if $SUDO sh -c "$*" >>"$OUTDIR/$f.log" 2>&1; then
    true
  else
    echo "(command exited non-zero)" >>"$OUTDIR/$f.log"
  fi
}

# Basic system info
echo "timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$OUTDIR/meta.txt"
uname -a >>"$OUTDIR/meta.txt" 2>&1 || true
id >>"$OUTDIR/meta.txt" 2>&1 || true
echo "cwd: $(pwd)" >>"$OUTDIR/meta.txt"
echo "user: $(whoami)" >>"$OUTDIR/meta.txt"

# Environment
env | sort >"$OUTDIR/env.txt" || true

# Journals for relevant units
run journal-dbus-broker "$SUDO journalctl -u dbus-broker.service -b --no-pager -n 1000"
run journal-dbus "$SUDO journalctl -u dbus.service -b --no-pager -n 1000"
run journal-polkit "$SUDO journalctl -u polkit.service -b --no-pager -n 800"
run journal-apparmor "$SUDO journalctl -u apparmor.service -b --no-pager -n 400"
run journal-switch-unit "$SUDO journalctl -u nixos-rebuild-switch-to-configuration -b --no-pager -n 1200 || true"

# Grep the boot journal for key errors / signs
if $SUDO sh -c "journalctl -b --no-pager -n 2000" >/dev/null 2>&1; then
  $SUDO journalctl -b --no-pager -n 2000 | rg -n "dbus|dbus-broker|polkit|switch-to-configuration|Rejected send message|Failed to reload|Failed to restart|error:" >"$OUTDIR/journal-grep.txt" || true
else
  journalctl -b --no-pager -n 2000 | rg -n "dbus|dbus-broker|polkit|switch-to-configuration|Rejected send message|Failed to reload|Failed to restart|error:" >"$OUTDIR/journal-grep.txt" || true
fi

# systemd unit statuses
run status-dbus-broker "$SUDO systemctl status dbus-broker.service --no-pager"
run status-dbus "$SUDO systemctl status dbus.service --no-pager"
run status-polkit "$SUDO systemctl status polkit.service --no-pager"
run status-apparmor "$SUDO systemctl status apparmor.service --no-pager"
run list-failed "$SUDO systemctl list-units --state=failed --no-pager"

# Show if switch transient unit exists
run status-switch-transient "$SUDO systemctl status nixos-rebuild-switch-to-configuration --no-pager || true"

# file lists useful for diagnosing missing binaries
run sw-bin-list "$SUDO ls -la /run/current-system/sw/bin || true"
run check-bash-ssh "$SUDO ls -la /run/current-system/sw/bin | rg -n 'bash|ssh' || true"

# dmesg tail
if $SUDO sh -c "dmesg -T -l emerg,alert,crit,err,warn | tail -n 200" >/dev/null 2>&1; then
  $SUDO dmesg -T -l emerg,alert,crit,err,warn | tail -n 200 >"$OUTDIR/dmesg-warn-tail.txt" || true
fi

# capture systemctl show of dbus-broker for properties
run show-dbus-broker "$SUDO systemctl show dbus-broker.service --property=ActiveState,SubState,Result,ExecMainPID || true"

# tar the result for easy upload
tar -czf "$OUTDIR.tar.gz" -C "$(dirname "$OUTDIR")" "$(basename "$OUTDIR")"

echo "Collected logs in: $OUTDIR"
echo "Archive: $OUTDIR.tar.gz"
echo "You can upload the tar.gz or paste selected log excerpts here."
