#!/run/current-system/sw/bin/bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 --input /path/to/creds.gpg --out /etc/samba/creds.d/<host>
This decrypts a GPG-encrypted credentials file and writes it to the target path
with owner root:root and mode 600. If input is missing, exits 0 (no-op).
EOF
}

INPUT=""
OUT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --input) INPUT="$2"; shift 2;;
    --out) OUT="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1"; usage; exit 2;;
  esac
done

if [ -z "$INPUT" ] || [ -z "$OUT" ]; then
  usage; exit 2
fi

if [ ! -f "$INPUT" ]; then
  echo "Encrypted creds file not found: $INPUT" >&2
  echo "No-op: leaving $OUT unchanged." >&2
  exit 0
fi

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

echo "Decrypting $INPUT -> $OUT"
gpg --batch --yes --output "$tmp" --decrypt "$INPUT"
chmod 600 "$tmp"
sudo mkdir -p "$(dirname "$OUT")"
sudo mv "$tmp" "$OUT"
sudo chown root:root "$OUT"
sudo chmod 600 "$OUT"
echo "Wrote $OUT"
