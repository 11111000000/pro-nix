#!/run/current-system/sw/bin/bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 --input /path/to/authorized_keys.gpg --out /var/lib/pro-peer/authorized_keys
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
  # Do not treat missing encrypted keys as a fatal error. It's common for
  # operator-managed secrets to be absent on a fresh system; in that case
  # log and exit successfully so the oneshot service does not cause
  # `nixos-rebuild switch` to fail. The operator can populate
  # /etc/pro-peer/authorized_keys.gpg later and trigger the service.
  echo "Encrypted keys file not found: $INPUT" >&2
  echo "No-op: leaving /var/lib/pro-peer/authorized_keys unchanged." >&2
  exit 0
fi

DRY_RUN=0
BACKUP=1
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift;;
    --no-backup) BACKUP=0; shift;;
    --input|--out) shift 2;;
    *) shift;;
  esac
done

tmp=$(mktemp "$OUT.tmp.XXXXXX")
trap 'rm -f "$tmp"' EXIT

echo "Decrypting $INPUT -> $tmp"
if ! gpg --batch --yes --decrypt --output "$tmp" "$INPUT"; then
  echo "GPG decrypt failed" >&2
  [ "$DRY_RUN" -eq 1 ] && echo "dry-run: skipping failure" && exit 0
  exit 3
fi
chmod 600 "$tmp"
mkdir -p "$(dirname "$OUT")"

if [ -f "$OUT" ] && [ "$BACKUP" -eq 1 ]; then
  backup="${OUT}.bak.$(date -u +%Y%m%dT%H%M%SZ)"
  echo "Backing up existing $OUT -> $backup"
  if [ "$DRY_RUN" -eq 0 ]; then
    cp -p "$OUT" "$backup"
  else
    echo "dry-run: would copy $OUT to $backup"
  fi
fi

if [ "$DRY_RUN" -eq 1 ]; then
  echo "dry-run: would move $tmp -> $OUT and set owner/permissions"
  exit 0
fi

mv "$tmp" "$OUT"
chown root:root "$OUT"
chmod 600 "$OUT"
echo "Wrote $OUT"
