#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 [discover|mount <host> [share]|umount <mountpoint>|mount-all]

Commands:
  discover          - list discovered _smb._tcp services via avahi-browse
  mount <host> [sh] - mount first share from <host>.local (or explicit share)
  umount <path>     - unmount the given mountpoint
  mount-all         - attempt to mount public share from all discovered hosts into /mnt/hosts/<host>
EOF
}

AVAHI_BROWSE=${AVAHI_BROWSE:-avahi-browse}
SMBCLIENT=${SMBCLIENT:-smbclient}
MOUNT_CIFS=${MOUNT_CIFS:-mount.cifs}

discover() {
  # show services
  $AVAHI_BROWSE -rt _smb._tcp | sed -n '1,200p'
}

mount_host() {
  host=$1
  share=${2:-}
  hostfqdn="${host%.local}.local"
  # find shares via smbclient
  if [ -z "$share" ]; then
    share=$($SMBCLIENT -L "//$hostfqdn" -N 2>/dev/null | awk -F" " '/Disk/ {print $1; exit}')
    if [ -z "$share" ]; then
      echo "No shares found on $hostfqdn" >&2
      return 1
    fi
  fi
  mountpoint="/mnt/hosts/$host/$share"
  sudo mkdir -p "$mountpoint"
  # Try guest mount first
  if sudo $MOUNT_CIFS "//$hostfqdn/$share" "$mountpoint" -o guest,vers=3.0; then
    echo "Mounted //$hostfqdn/$share -> $mountpoint (guest)"
    return 0
  fi
  echo "Guest mount failed; please provide credentials via /etc/samba/creds.d/$host" >&2
  if [ -f "/etc/samba/creds.d/$host" ]; then
    sudo $MOUNT_CIFS "//$hostfqdn/$share" "$mountpoint" -o credentials=/etc/samba/creds.d/$host,vers=3.0
    echo "Mounted //$hostfqdn/$share -> $mountpoint (credentials)"
    return 0
  fi
  echo "No credentials found; mount failed." >&2
  return 2
}

umount_path() {
  path=$1
  sudo umount "$path"
}

mount_all() {
  # discover hosts and mount their first share under /mnt/hosts/<host>
  mapfile -t hosts < <($AVAHI_BROWSE -rt _smb._tcp | awk '/^=/ {print $8}' | sed 's/\.$//g' | sed 's/\.local$//' | sort -u)
  for h in "${hosts[@]}"; do
    echo "Mounting $h..."
    mount_host "$h" || true
  done
}

case "${1:-}" in
  discover) discover;;
  mount) shift; mount_host "$@";;
  umount) shift; umount_path "$@";;
  mount-all|mount_all) mount_all;;
  -h|--help|"") usage;;
  *) echo "unknown cmd: $1"; usage; exit 2;;
esac
