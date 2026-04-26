#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 --hidden-dir /var/lib/tor/ssh_hidden_service --recipient '<gpg-recipient>' --out-dir /var/lib/pro-peer
EOF
}

HIDDENDIR=""
RECIP=""
OUTDIR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --hidden-dir) HIDDENDIR="$2"; shift 2;;
    --recipient) RECIP="$2"; shift 2;;
    --out-dir) OUTDIR="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1"; usage; exit 2;;
  esac
done

if [ -z "$HIDDENDIR" ] || [ -z "$RECIP" ] || [ -z "$OUTDIR" ]; then
  usage; exit 2
fi

if [ ! -d "$HIDDENDIR" ]; then
  echo "Hidden dir not found: $HIDDENDIR" >&2; exit 1
fi

mkdir -p "$OUTDIR"
tar -C "$HIDDENDIR" -czf - . | gpg --batch --yes --encrypt --recipient "$RECIP" -o "$OUTDIR/hiddenservice-$(date +%Y%m%d%H%M).tar.gz.gpg"
echo "Backup written to $OUTDIR"
