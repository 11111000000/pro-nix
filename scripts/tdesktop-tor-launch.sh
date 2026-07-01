#!/usr/bin/env bash
# scripts/tdesktop-tor-launch.sh
# Wrapper для Telegram Desktop — оборачивает запуск через torsocks когда
# доступен SOCKS5 endpoint. Иначе запускает напрямую (fallback).
#
# Логика:
#   1. Проверяет SOCKS5 на 127.0.0.1:9050 (Tor по умолчанию).
#   2. Если Tor отвечает — запускает через `torsocks telegram-desktop ...`.
#   3. Если нет — запускает `telegram-desktop ...` напрямую (best-effort).
#   4. Возвращает exit code оригинального процесса.
#
# Принцип работы torsocks:
#   Перехватывает системные вызовы connect() и редиректит TCP через
#   SOCKS5 (с LD_PRELOAD). Это прозрачно для программ без нативной
#   поддержки SOCKS5 прокси (Telegram Desktop = Qt-приложение).
#
# Usage:
#   ./scripts/tdesktop-tor-launch.sh            # запуск GUI TDesktop
#   ./scripts/tdesktop-tor-launch.sh --debug    # verbose
#   ./scripts/tdesktop-tor-launch.sh --check    # только проверка Tor
#
# Environment:
#   PRO_TELEGRAM_TOR_HOST  default 127.0.0.1
#   PRO_TELEGRAM_TOR_PORT  default 9050
#   PRO_TELEGRAM_DISABLE_TOR=1 — force disable, всегда fallback
#
# Exit codes:
#   0  — TDesktop закрылся чисто
#   1  — Tor SOCKS5 не отвечает, fallback выполнен
#   rc — exit code TDesktop (если запуск дошёл до неё)

set -uo pipefail
HOST="${PRO_TELEGRAM_TOR_HOST:-127.0.0.1}"
PORT="${PRO_TELEGRAM_TOR_PORT:-9050}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEBUG=0
CHECK_ONLY=0

for arg in "$@"; do
  case "$arg" in
    --debug) DEBUG=1 ;;
    --check) CHECK_ONLY=1 ;;
    -h|--help)
      sed -n '2,30p' "$0"
      exit 0
      ;;
  esac
done

log() { [ "$DEBUG" -eq 1 ] && echo "[tdesktop-tor] $*" >&2 || true; }

if [ -n "${PRO_TELEGRAM_DISABLE_TOR:-}" ]; then
  log "PRO_TELEGRAM_DISABLE_TOR set — forcing direct launch"
  TOR_AVAILABLE=0
else
  if "$SCRIPT_DIR/check-tor-socks.sh" --host "$HOST" --port "$PORT" >/dev/null 2>&1; then
    log "Tor SOCKS5 reachable at ${HOST}:${PORT}"
    TOR_AVAILABLE=1
  else
    log "Tor SOCKS5 unavailable at ${HOST}:${PORT} (fallback to direct)"
    TOR_AVAILABLE=0
  fi
fi

if [ "$CHECK_ONLY" -eq 1 ]; then
  if [ "$TOR_AVAILABLE" -eq 1 ]; then
    echo "Tor SOCKS5 OK at ${HOST}:${PORT}"
    exit 0
  else
    echo "Tor SOCKS5 NOT available at ${HOST}:${PORT}"
    exit 1
  fi
fi

if [ "$TOR_AVAILABLE" -eq 1 ]; then
  if command -v torsocks >/dev/null 2>&1; then
    echo "[tdesktop-tor-launch] Tor available — launching via torsocks" >&2
    exec torsocks telegram-desktop "$@"
  else
    echo "[tdesktop-tor-launch] WARNING: Tor available but torsocks NOT installed" >&2
    echo "[tdesktop-tor-launch] Install: services.tor.client.enable + torsocks in environment.systemPackages" >&2
    echo "[tdesktop-tor-launch] Falling back to direct launch" >&2
  fi
else
  echo "[tdesktop-tor-launch] Tor NOT available — direct launch (no proxy)" >&2
fi

exec telegram-desktop "$@"
