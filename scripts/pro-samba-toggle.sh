#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 [status|on|off|restart]
  status  - show Samba/Avahi service status and listening ports
  on      - start and enable Samba and Avahi now
  off     - stop Samba now (does not change NixOS config)
  restart - restart Samba services
EOF
}

cmd="${1:-status}"

svc_smbd="samba-smbd"
svc_nmbd="samba-nmbd"
svc_avahi="avahi-daemon"

case "$cmd" in
  status)
    systemctl --no-pager --full status "$svc_smbd" "$svc_nmbd" "$svc_avahi" || true
    echo
    echo "Listening ports:"
    ss -ltnp | grep -E ':(139|445)' || true
    ;;
  on)
    sudo systemctl enable --now "$svc_avahi" || true
    sudo systemctl enable --now "$svc_smbd" || true
    sudo systemctl enable --now "$svc_nmbd" || true
    ;;
  off)
    sudo systemctl stop "$svc_nmbd" || true
    sudo systemctl stop "$svc_smbd" || true
    ;;
  restart)
    sudo systemctl restart "$svc_smbd" || true
    sudo systemctl restart "$svc_nmbd" || true
    ;;
  *)
    usage
    exit 1
    ;;
esac
