#!/usr/bin/env bash
# ops-wifi-recover.sh — восстановление Wi-Fi после суспенда
#
# Назначение: перезапускает Wi-Fi радио через NetworkManager после выхода из
#   суспенда (s2idle/S3). Использует эскалирующие стратегии:
#   1. nmcli radio toggle
#   2. nmcli connection reload + up
#   3. systemctl try-restart NetworkManager
#
# Контракт: скрипт не завершается с ошибкой (exit 0 при успехе любой попытки).
# Проверка: ./scripts/ops-wifi-recover.sh --dry-run

set -euo pipefail

NMCLI="${NMCLI:-nmcli}"
SLEEP="${SLEEP:-2}"
PING_TARGET="${PING_TARGET:-8.8.8.8}"
PING_COUNT="${PING_COUNT:-1}"

usage() {
  cat <<EOF
Usage: $(basename "$0") [--dry-run]

Восстанавливает Wi-Fi соединение после суспенда.
  --dry-run  только показать, что будет сделано
EOF
}

log()  { echo "[wifi-recover] $*"; }
err()  { echo "[wifi-recover] ERROR: $*" >&2; }

dry_run=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) dry_run=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) err "Неизвестный аргумент: $1"; usage; exit 2 ;;
  esac
done

step() {
  local desc="$1"; shift
  log "$desc"
  if [[ $dry_run -eq 1 ]]; then
    log "  (dry-run) $*"
    return 0
  fi
  "$@" && return 0
  err "не удалось: $*"
  return 1
}

check_connectivity() {
  if command -v ping &>/dev/null; then
    ping -c "$PING_COUNT" -W 2 "$PING_TARGET" &>/dev/null
  else
    # fallback: проверяем, есть ли активное NM-соединение
    $NMCLI -t -f STATE connection show --active 2>/dev/null | grep -q activated
  fi
}

# === Стратегия 0: ничего не делать, если всё уже работает ===
if check_connectivity; then
  log "соединение уже активно"
  exit 0
fi

log "соединения нет — запускаю восстановление"

# === Стратегия 1: сброс Wi-Fi радио ===
if step "сброс Wi-Fi радио" $NMCLI radio wifi off; then
  sleep "$SLEEP"
  step "включение Wi-Fi радио" $NMCLI radio wifi on || true
  sleep "$SLEEP"
  if check_connectivity; then
    log "восстановлено: сброс радио"
    exit 0
  fi
fi

# === Стратегия 2: перезагрузка соединений NM ===
if step "перезагрузка конфигурации NM" $NMCLI connection reload; then
  sleep 1
  # поднимаем все известные wifi-соединения
  while IFS= read -r conn; do
    step "подключение: $conn" $NMCLI connection up "$conn" 2>/dev/null || true
  done < <($NMCLI -t -f NAME,TYPE connection show 2>/dev/null | grep -E ':wifi$' | cut -d: -f1 || true)
  sleep "$SLEEP"
  if check_connectivity; then
    log "восстановлено: reload + up"
    exit 0
  fi
fi

# === Стратегия 3: перезапуск NM ===
if step "перезапуск NetworkManager" systemctl try-restart NetworkManager; then
  sleep "$((SLEEP * 2))"
  if check_connectivity; then
    log "восстановлено: перезапуск NM"
    exit 0
  fi
fi

err "все стратегии исчерпаны, соединение не восстановлено"
exit 1
