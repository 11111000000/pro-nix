#!/usr/bin/env bash
# scripts/check-tor-socks.sh
# Проверить, доступен ли Tor SOCKS5 endpoint на указанном host:port.
# Возвращает 0 если доступен, non-zero иначе. Печатает детали в stderr
# при -v/--verbose.
#
# Используется в pro-telegram.nix и pro-privacy для условного запуска
# приложений через torsocks. По умолчанию проверяет 127.0.0.1:9050
# (стандартный системный Tor из services.tor.client.enable).
#
# Поддерживает 3 уровня проверки:
#   --level tcp   # только TCP connect (быстро, 0.5s)
#   --level socks # TCP + попытка SOCKS5 handshake (медленнее, ~1s)
#   --level onion # + resolve .onion через Tor (полная проверка, 2-5s)
# По умолчанию --level socks (достаточно для условного decision).
#
# Usage:
#   ./scripts/check-tor-socks.sh                         # exit 0/1
#   ./scripts/check-tor-socks.sh --host 192.168.1.1 --port 9050
#   ./scripts/check-tor-socks.sh -v                     # печатает детали
#   ./scripts/check-tor-socks.sh --level onion          # полная проверка
#
# Exit codes:
#   0 — Tor SOCKS5 reachable and accepts handshake
#   1 — TCP connect failed (host down/refused)
#   2 — TCP OK but SOCKS5 handshake failed (wrong daemon or proxy)
#   3 — SOCKS5 OK but .onion resolve failed (DNS leak)
#   4 — invalid args

set -euo pipefail
HOST="127.0.0.1"
PORT="9050"
LEVEL="socks"
VERBOSE=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --host) HOST="$2"; shift 2;;
    --port) PORT="$2"; shift 2;;
    --level) LEVEL="$2"; shift 2;;
    -v|--verbose) VERBOSE=1; shift;;
    -h|--help)
      sed -n '2,30p' "$0"
      exit 0
      ;;
    *) echo "Unknown arg: $1" >&2; exit 4;;
  esac
done

log() { [ "$VERBOSE" -eq 1 ] && echo "[check-tor-socks] $*" >&2 || true; }

# Step 1: TCP connect (timeout 1s)
log "TCP connect to ${HOST}:${PORT} ..."
if ! timeout 1 bash -c "</dev/tcp/${HOST}/${PORT}" 2>/dev/null; then
  log "TCP connect failed: ${HOST}:${PORT} unreachable"
  exit 1
fi
log "TCP connect OK"

# Step 2 (default --level socks): SOCKS5 handshake
# Отправляем минимальный SOCKS5 greeting: version=5, nmethods=1,
# method=0 (no-auth). Ответ должен быть version=5, method=0.
test_socks5() {
  local req=$(printf '\x05\x01\x00')
  local resp
  # shellcheck disable=SC2086
  resp=$(timeout 1 bash -c "
    exec 3<>/dev/tcp/${HOST}/${PORT}
    printf '%s' \"\$0\" >&3
    head -c 2 <&3
  " "$req" 2>/dev/null || true)
  # resp = version byte + method byte
  local version="${resp:0:1}"
  local method="${resp:1:1}"
  if [ "$version" = $'\x05' ] && [ "$method" = $'\x00' ]; then
    return 0
  elif [ "$version" = $'\x05' ]; then
    # Got SOCKS5 reply but different method (likely auth required, e.g. 0x02)
    return 2
  fi
  return 1
}

if [ "$LEVEL" = "tcp" ]; then
  log "skipping SOCKS5 handshake (--level tcp)"
  exit 0
fi

log "SOCKS5 handshake to ${HOST}:${PORT} ..."
# Use Python for binary-safe SOCKS5 handshake
if command -v python3 >/dev/null 2>&1; then
  python3 - "$HOST" "$PORT" <<'PYEOF'
import socket, sys
host, port = sys.argv[1], int(sys.argv[2])
try:
    s = socket.create_connection((host, port), timeout=2)
except OSError as e:
    print(f"TCP failed: {e}", file=sys.stderr)
    sys.exit(1)
s.sendall(b"\x05\x01\x00")
s.settimeout(2)
try:
    data = s.recv(2)
except socket.timeout:
    print("SOCKS5 timeout", file=sys.stderr)
    sys.exit(2)
s.close()
if len(data) != 2 or data[0] != 5:
    print(f"Bad SOCKS5 reply: {data!r}", file=sys.stderr)
    sys.exit(2)
if data[1] != 0:
    print(f"SOCKS5 needs auth method={data[1]} (not 0=no-auth)", file=sys.stderr)
    sys.exit(2)
print("SOCKS5 handshake OK", file=sys.stderr)
PYEOF
  rc=$?
  if [ $rc -ne 0 ]; then
    log "SOCKS5 handshake failed (rc=$rc)"
    exit "$rc"
  fi
  log "SOCKS5 handshake OK"
else
  if ! test_socks5; then
    log "SOCKS5 handshake failed"
    exit 2
  fi
  log "SOCKS5 handshake OK"
fi

# Step 3 (--level onion): проверка разрешения .onion адреса через Tor
if [ "$LEVEL" = "onion" ]; then
  log "Resolving duckduckgooggylanxjogarv.onion via Tor ..."
  ONION_RESP=$(timeout 5 python3 - "$HOST" "$PORT" <<'PYEOF'
import socket, sys
host, port = sys.argv[1], int(sys.argv[2])
s = socket.create_connection((host, port), timeout=2)
s.sendall(b"\x05\x01\x00")
assert s.recv(2) == b"\x05\x00", "SOCKS5 not no-auth"
# SOCKS5 CONNECT to duckduckgooggylanxjogarv.onion:80
req = b"\x05\x01\x00\x01" + b"\x00" * 4 + b"\x00\x50"
onion = b"duckduckgooggylanxjogarv.onion"
req += bytes([len(onion)]) + onion
s.sendall(req)
s.settimeout(4)
resp = s.recv(10)
s.close()
if len(resp) >= 4 and resp[1] == 0:
    print("Onion resolve OK (Tor resolves .onion)", file=sys.stderr)
    sys.exit(0)
print(f"Onion resolve failed: {resp!r}", file=sys.stderr)
sys.exit(3)
PYEOF
    )
  rc=$?
  if [ $rc -ne 0 ]; then
    log "Onion resolve failed (rc=$rc)"
    exit "$rc"
  fi
fi

exit 0
