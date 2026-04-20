#!/usr/bin/env bash
set -euo pipefail

# pro-peer-master.sh
# Usage:
#  ./scripts/pro-peer-master.sh --hosts cf19.local,huawei.local --file ./authorized_keys.gpg
#
# This script securely copies an already-GPG-encrypted authorized_keys.gpg to a list
# of hosts and triggers the pro-peer sync service. It is cautious: creates backups,
# validates connectivity, and never writes plaintext keys remotely.

usage() {
  cat <<EOF
Usage: $0 --hosts host1,host2 --file /path/to/authorized_keys.gpg

Options:
  --hosts   Comma-separated list of hosts (mDNS names like cf19.local)
  --file    Path to GPG-encrypted authorized_keys.gpg
  --user    SSH user to use (default: $USER)
  --help    Show this help
EOF
}

HOSTS=""
FILE=""
USER=${USER}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --hosts) HOSTS="$2"; shift 2;;
    --file) FILE="$2"; shift 2;;
    --user) USER="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1"; usage; exit 2;;
  esac
done

if [ -z "$HOSTS" ] || [ -z "$FILE" ]; then
  usage; exit 2
fi

if [ ! -f "$FILE" ]; then
  echo "File not found: $FILE" >&2; exit 1
fi

IFS=',' read -r -a HOST_ARR <<< "$HOSTS"

LOGFILE="$HOME/.local/share/pro-peer/master.log"
mkdir -p "$(dirname "$LOGFILE")"

echo "=== pro-peer-master: starting at $(date -Iseconds)" | tee -a "$LOGFILE"

for h in "${HOST_ARR[@]}"; do
  echo "-> Host: $h" | tee -a "$LOGFILE"
  # 1) test connectivity
  if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "$USER@$h" true; then
    echo "  [ERROR] Cannot SSH to $h" | tee -a "$LOGFILE"
    continue
  fi

  # 2) upload encrypted file to temp path
  remote_tmp="/var/lib/pro-peer/authorized_keys.gpg.tmp.$(date +%s)"
  echo "  uploading encrypted file to $h:$remote_tmp" | tee -a "$LOGFILE"
  if ! scp -q "$FILE" "$USER@$h:$remote_tmp"; then
    echo "  [ERROR] scp failed for $h" | tee -a "$LOGFILE"
    continue
  fi

  # 3) on remote: backup existing file (if any), then move tmp -> target, set perms, and restart service
  remote_cmd=$(cat <<'EOF'
set -e
TARGET=/etc/pro-peer/authorized_keys.gpg
BACKUP_DIR=/var/lib/pro-peer/backups
mkdir -p "$BACKUP_DIR"
if [ -f "$TARGET" ]; then
  cp -p "$TARGET" "$BACKUP_DIR/authorized_keys.gpg.$(date +%s)" || true
fi
mv -f "${remote_tmp}" "$TARGET"
chown root:root "$TARGET"
chmod 600 "$TARGET"
systemctl restart pro-peer-sync-keys.service || true
sleep 1
systemctl is-active --quiet pro-peer-sync-keys.service && echo "SYNC_OK" || echo "SYNC_FAILED"
EOF
)

  echo "  running remote provisioning..." | tee -a "$LOGFILE"
  if ssh "$USER@$h" bash -s -- "$remote_tmp" <<< "$remote_cmd" | tee -a "$LOGFILE" | grep -q SYNC_OK; then
    echo "  [OK] keys installed and sync triggered on $h" | tee -a "$LOGFILE"
  else
    echo "  [ERROR] remote sync failed on $h; see log" | tee -a "$LOGFILE"
  fi
done

echo "=== pro-peer-master: finished at $(date -Iseconds)" | tee -a "$LOGFILE"
