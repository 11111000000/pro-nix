#!/usr/bin/env bash
set -euo pipefail

# ensure-tor.sh
# Safely ensure Tor can start with bridges and pluggable transports on NixOS.
# Run as root (sudo).

REPO_CANDIDATES=( "$PWD" "$PWD/.." /home/az/pro-nix /etc/nixos )
REPO=""
for p in "${REPO_CANDIDATES[@]}"; do
  if [ -f "$p/configuration.nix" ]; then
    REPO="$p"
    break
  fi
done

timestamp() { date +%Y%m%dT%H%M%S; }

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  echo "This script must be run as root. Use sudo." >&2
  exit 2
fi

echo "[info] repo detected: ${REPO:-(none)}"

echo "[step] Ensure /var/lib/tor exists with correct owner/mode"
if [ ! -d /var/lib/tor ]; then
  mkdir -p /var/lib/tor
fi
chown -R tor:tor /var/lib/tor || true
chmod 700 /var/lib/tor || true
echo "  -> /var/lib/tor: $(stat -c '%U:%G %a' /var/lib/tor)"

echo "[step] Ensure bridges file exists"
if [ ! -f /etc/tor/bridges.conf ] || [ ! -s /etc/tor/bridges.conf ]; then
  if [ -n "$REPO" ] && [ -f "$REPO/conf/tor-bridges.conf" ]; then
    echo "  -> copying example bridges.conf from repo to /etc/tor/bridges.conf"
    cp "$REPO/conf/tor-bridges.conf" /etc/tor/bridges.conf
    chown root:root /etc/tor/bridges.conf
    chmod 0640 /etc/tor/bridges.conf
  else
    echo "  -> WARNING: /etc/tor/bridges.conf missing or empty and no example found in repo"
  fi
else
  echo "  -> /etc/tor/bridges.conf exists and is non-empty"
fi

TORRC=/etc/tor/torrc
echo "[step] Ensure /etc/tor/torrc contains Include and UseBridges and ClientTransportPlugin lines"
if [ -f "$TORRC" ]; then
  bak="$TORRC.bak.$(timestamp)"
  cp "$TORRC" "$bak"
  echo "  -> backup written to $bak"
else
  touch "$TORRC"
fi

ensure_line() {
  local file="$1"; shift
  local line="$*"
  if ! grep -F -x -q "$line" "$file"; then
    echo "$line" >> "$file"
    echo "    added: $line"
  else
    echo "    present: $line"
  fi
}

ensure_line "$TORRC" "Include /etc/tor/bridges.conf"
ensure_line "$TORRC" "UseBridges 1"
ensure_line "$TORRC" "ClientTransportPlugin obfs4 exec /run/current-system/sw/bin/obfs4proxy"
ensure_line "$TORRC" "ClientTransportPlugin snowflake exec /run/current-system/sw/bin/snowflake-client"
ensure_line "$TORRC" "ClientTransportPlugin meek exec /run/current-system/sw/bin/meek-client"

echo "[step] Check for pluggable transport binaries"
MISSING_BIN=()
for b in /run/current-system/sw/bin/obfs4proxy /run/current-system/sw/bin/snowflake-client /run/current-system/sw/bin/meek-client; do
  if [ ! -x "$b" ]; then
    MISSING_BIN+=("$b")
  fi
done

if [ ${#MISSING_BIN[@]} -eq 0 ]; then
  echo "  -> all pluggable transport binaries present"
else
  echo "  -> missing binaries: ${MISSING_BIN[*]}"
  if [ -n "$REPO" ] && [ -f "$REPO/configuration.nix" ]; then
    echo "[info] Attempting nixos-rebuild to install transports (this may take time)."
    # Attempt a non-interactive rebuild using the repository configuration if available
    if command -v nixos-rebuild >/dev/null 2>&1; then
      echo "  -> running: nixos-rebuild switch -I nixos-config=$REPO/configuration.nix"
      if nixos-rebuild switch -I nixos-config="$REPO/configuration.nix"; then
        echo "  -> nixos-rebuild succeeded"
      else
        echo "  -> nixos-rebuild failed; you may need to run it manually and inspect errors" >&2
      fi
    else
      echo "  -> nixos-rebuild not found on PATH; cannot install transports automatically" >&2
    fi
  else
    echo "  -> repository configuration not found; cannot auto-install transports" >&2
  fi
fi

echo "[step] Restart and enable tor.service"
if command -v systemctl >/dev/null 2>&1; then
  systemctl daemon-reload || true
  systemctl enable --now tor.service || true
  sleep 2
  systemctl status tor.service --no-pager -l || true
else
  echo "  -> systemctl not found; cannot manage tor.service" >&2
fi

echo "[step] Show recent tor logs (last 200 lines)"
if command -v journalctl >/dev/null 2>&1; then
  journalctl -u tor.service -n 200 --no-pager || true
fi

echo "[step] Test SOCKS proxy (will try a HEAD request via 127.0.0.1:9050)"
if command -v curl >/dev/null 2>&1; then
  if curl --socks5-hostname 127.0.0.1:9050 -I https://check.torproject.org/ -m 20; then
    echo "[ok] SOCKS proxy responded"
  else
    echo "[warn] SOCKS proxy test failed — check tor.service logs above"
  fi
else
  echo "  -> curl not found; skipping connectivity test"
fi

echo "[done] Script finished. Inspect output above for errors. If tor still fails, copy the journalctl output and send it for analysis."
