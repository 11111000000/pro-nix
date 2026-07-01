#!/usr/bin/env bash
# scripts/telega-server-tor-launch.sh
# Wrapper для telega-server (из `pkgs.telega-server`) — tor-conditional
# SOCKS5 proxy. Telega-server это бинарь tdlib-bridge; tdlib НЕ
# поддерживает SOCKS5 из коробки через elisp, но `torsocks` оборачивает
# все TCP-вызовы процесса, что эквивалентно системному proxy.
#
# Используется pro-chat.el / telega.el когда у пользователя включен Tor.
# По умолчанию запускает `telega-server --forward=tcp:*:<port>:127.0.0.1:<port>`
# через torsocks если Tor доступен, иначе — напрямую.
#
# Variables:
#   PRO_TELEGRAM_TOR_HOST/PORT — default 127.0.0.1:9050
#   PRO_TELEGA_PORT    — port for telega-server (default 6056)
#   PRO_TELEGRAM_DISABLE_TOR=1 — force direct
#
# Usage:
#   ./scripts/telega-server-tor-launch.sh --port 6056
#   ./scripts/telega-server-tor-launch.sh --check

set -uo pipefail
HOST="${PRO_TELEGRAM_TOR_HOST:-127.0.0.1}"
PORT="${PRO_TELEGRAM_TOR_PORT:-9050}"
TG_PORT="${PRO_TELEGA_PORT:-6056}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEBUG=0
CHECK_ONLY=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --port) TG_PORT="$2"; shift 2;;
    --host) HOST="$2"; shift 2;;
    --check) CHECK_ONLY=1; shift;;
    --debug) DEBUG=1; shift;;
    -h|--help)
      sed -n '2,30p' "$0"
      exit 0
      ;;
    *) break;;
  esac
done

log() { [ "$DEBUG" -eq 1 ] && echo "[telega-server-tor] $*" >&2 || true; }

if [ -n "${PRO_TELEGRAM_DISABLE_TOR:-}" ]; then
  log "PRO_TELEGRAM_DISABLE_TOR set — forcing direct"
  TOR_AVAILABLE=0
else
  if "$SCRIPT_DIR/check-tor-socks.sh" --host "$HOST" --port "$PORT" >/dev/null 2>&1; then
    log "Tor SOCKS5 reachable at ${HOST}:${PORT}"
    TOR_AVAILABLE=1
  else
    log "Tor not available (fallback)"
    TOR_AVAILABLE=0
  fi
fi

if [ "$CHECK_ONLY" -eq 1 ]; then
  [ "$TOR_AVAILABLE" -eq 1 ] && exit 0 || exit 1
fi

# telega-server forwarding options: --forward=tcp:127.0.0.1:<port>:* listens
# on 127.0.0.1:<port>. By default we use the same port.
ARGS=("$@" "--forward=tcp:127.0.0.1:${TG_PORT}:127.0.0.1:${TG_PORT}")

if [ "$TOR_AVAILABLE" -eq 1 ]; then
  if command -v torsocks >/dev/null 2>&1; then
    log "torsocks telega-server ${ARGS[*]}"
    exec torsocks telega-server "${ARGS[@]}"
  fi
fi

log "direct telega-server ${ARGS[*]}"
exec telega-server "${ARGS[@]}"
