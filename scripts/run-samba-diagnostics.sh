#!/usr/bin/env bash
set -euo pipefail

OUTDIR="${1:-./logs/diagnostics}"
TS=$(date +%Y%m%d-%H%M%S)
OUT="$OUTDIR/pro-nix-diagnostics-$TS.log"
mkdir -p "$OUTDIR"

echo "Diagnostics log: $OUT"
exec > >(tee -a "$OUT") 2>&1

hr() { printf "\n%0s\n" "------------------------------------------------------------"; }
run() {
  echo
  hr
  echo "CMD: $*"
  echo
  bash -lc "$*" || true
}

echo "Pro-nix diagnostics run: $TS"
echo "cwd: $(pwd)"
echo "user: $(id -un) (uid=$(id -u))"
echo "host: $(hostname)"

run "date"
run "uname -a"

# Nix info
run "nixos-version || true"
run "nix --version || true"
run "nix flake show . || true"

# Check whether we can run sudo without prompt. If not, we still run commands
# without sudo and capture errors.
SUDO_OK=0
if [ "$(id -u)" -eq 0 ]; then
  SUDO_CMD=""
  SUDO_OK=1
else
  if command -v sudo >/dev/null 2>&1; then
    if sudo -n true 2>/dev/null; then
      SUDO_CMD="sudo"
      SUDO_OK=1
    else
      SUDO_CMD="sudo"
      SUDO_OK=0
    fi
  else
    SUDO_CMD=""
    SUDO_OK=0
  fi
fi

echo "SUDO available: $SUDO_OK (SUDO_CMD='$SUDO_CMD')"

# Firewall / nftables / iptables
run "( $SUDO_CMD nft list table inet pro-nix-smb 2>/dev/null || $SUDO_CMD nft list ruleset 2>/dev/null | sed -n '/pro-nix-smb/,+40p' ) || ( $SUDO_CMD iptables -L -n 2>/dev/null | grep -E '139|445' || true )"

# Services
run "$SUDO_CMD systemctl status avahi-daemon pro-peer-sync-keys samba-nmbd samba-smbd --no-pager || true"

run "$SUDO_CMD journalctl -u samba-smbd -n 200 --no-pager || true"
run "$SUDO_CMD journalctl -u avahi-daemon -n 200 --no-pager || true"
run "$SUDO_CMD journalctl -u pro-peer-sync-keys -n 200 --no-pager || true"

# Files and dirs
run "ls -ld /run/avahi-daemon /var/lib/pro-peer /var/lib/pro-peer/authorized_keys || true"
run "ls -l /etc/pro-peer/authorized_keys.gpg || true"

# Samba config
run "testparm -s 2>/dev/null || true"

# Network
run "ip -4 addr show || true"

# Fail2ban
run "$SUDO_CMD systemctl status fail2ban --no-pager || true"
run "$SUDO_CMD fail2ban-client status || true"

hr
echo "Diagnostics written to: $OUT"
