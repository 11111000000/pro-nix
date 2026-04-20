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
DRY_RUN=0
ASSUME_YES=0
RETRIES=3
TIMEOUT=10
AUTO_ROLLBACK=0
SIGFILE=""
VERIFY_RECIPIENT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --hosts) HOSTS="$2"; shift 2;;
    --file) FILE="$2"; shift 2;;
    --user) USER="$2"; shift 2;;
    --dry-run) DRY_RUN=1; shift 1;;
    --yes) ASSUME_YES=1; shift 1;;
    --retries) RETRIES="$2"; shift 2;;
    --timeout) TIMEOUT="$2"; shift 2;;
    --auto-rollback) AUTO_ROLLBACK=1; shift 1;;
    --sig) SIGFILE="$2"; shift 2;;
    --verify-recipient) VERIFY_RECIPIENT="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1"; usage; exit 2;;
  esac
done

if [ -z "$HOSTS" ] || [ -z "$FILE" ]; then
  usage; exit 2
fi

if [ ! -f "$FILE" ]; then
  echo "Файл не найден: $FILE" >&2; exit 1
fi

# Если задан sig файл — либо явно, либо автоматически найдём рядом
if [ -z "$SIGFILE" ]; then
  if [ -f "${FILE}.sig" ]; then
    SIGFILE="${FILE}.sig"
  fi
fi

if [ -n "$SIGFILE" ]; then
  echo "Проверяю подпись $SIGFILE для $FILE..." | tee -a "$LOGFILE"
  if ! gpg --verify "$SIGFILE" "$FILE" >/dev/null 2>&1; then
    echo "[ERROR] Подпись не прошла проверку: $SIGFILE" | tee -a "$LOGFILE"
    exit 1
  else
    echo "Подпись: OK" | tee -a "$LOGFILE"
  fi
fi

# Если указан verify recipient, проверяем, что encrypted file предназначен для этого реципиента
if [ -n "$VERIFY_RECIPIENT" ]; then
  echo "Проверяю recipients в $FILE на наличие $VERIFY_RECIPIENT..." | tee -a "$LOGFILE"
  if ! gpg --list-packets --batch "$FILE" 2>/dev/null | grep -qi "$VERIFY_RECIPIENT"; then
    echo "[ERROR] Файл не содержит указанного реципиента: $VERIFY_RECIPIENT" | tee -a "$LOGFILE"
    exit 1
  else
    echo "Recipient check: OK" | tee -a "$LOGFILE"
  fi
fi

IFS=',' read -r -a HOST_ARR <<< "$HOSTS"

LOGFILE="$HOME/.local/share/pro-peer/master.log"
mkdir -p "$(dirname "$LOGFILE")"

echo "=== pro-peer-master: starting at $(date -Iseconds)" | tee -a "$LOGFILE"

for h in "${HOST_ARR[@]}"; do
  echo "-> Host: $h" | tee -a "$LOGFILE"

  # 1) test connectivity with retries
  ok=0
  for i in $(seq 1 $RETRIES); do
    echo "  Проверка SSH (попытка $i/$RETRIES)..." | tee -a "$LOGFILE"
    if ssh -o ConnectTimeout=$TIMEOUT -o BatchMode=yes "$USER@$h" true 2>/dev/null; then
      ok=1; break
    fi
    sleep $((i * 1))
  done
  if [ $ok -eq 0 ]; then
    echo "  [ERROR] Невозможно подключиться к $h по SSH" | tee -a "$LOGFILE"
    continue
  fi

  remote_tmp="/tmp/authorized_keys.gpg.tmp.$(date +%s)"
  echo "  Загрузка файла на $h:$remote_tmp" | tee -a "$LOGFILE"
  if [ $DRY_RUN -eq 1 ]; then
    echo "  (dry-run) не выполняю scp" | tee -a "$LOGFILE"
    continue
  fi

  if ! scp -o ConnectTimeout=$TIMEOUT -q "$FILE" "$USER@$h:$remote_tmp"; then
    echo "  [ERROR] scp не удался для $h" | tee -a "$LOGFILE"
    continue
  fi

  # 3) remote provisioning with sudo and atomic replacement
  remote_cmd=$(cat <<'EOF'
set -e
REMOTE_TMP="$1"
TARGET=/etc/pro-peer/authorized_keys.gpg
BACKUP_DIR=/var/lib/pro-peer/backups
sudo mkdir -p "$BACKUP_DIR"
if sudo test -f "$TARGET"; then
  sudo cp -p "$TARGET" "$BACKUP_DIR/authorized_keys.gpg.$(date +%s)" || true
fi
sudo mv -f "$REMOTE_TMP" "$TARGET"
sudo chown root:root "$TARGET"
sudo chmod 600 "$TARGET"
sudo systemctl restart pro-peer-sync-keys.service || true
sleep 1
if sudo systemctl is-active --quiet pro-peer-sync-keys.service; then
  echo "SYNC_OK"
else
  echo "SYNC_FAILED"
fi
EOF
)

  echo "  Выполняю удалённую установку..." | tee -a "$LOGFILE"
  if ssh -o ConnectTimeout=$TIMEOUT "$USER@$h" bash -s -- "$remote_tmp" <<< "$remote_cmd" | tee -a "$LOGFILE" | grep -q SYNC_OK; then
    echo "  [OK] ключи установлены и синхронизация запущена на $h" | tee -a "$LOGFILE"
  else
    echo "  [ERROR] remote sync failed on $h; see log" | tee -a "$LOGFILE"
    if [ $AUTO_ROLLBACK -eq 1 ]; then
      echo "  Пытаюсь откатить изменения на $h" | tee -a "$LOGFILE"
      ssh "$USER@$h" sudo bash -c 'LAST=$(ls -1t /var/lib/pro-peer/backups/authorized_keys.gpg.* 2>/dev/null | head -n1) || true; if [ -n "$LAST" ]; then mv -f "$LAST" /etc/pro-peer/authorized_keys.gpg && systemctl restart pro-peer-sync-keys.service; fi'
    fi
  fi
done

echo "=== pro-peer-master: finished at $(date -Iseconds)" | tee -a "$LOGFILE"
