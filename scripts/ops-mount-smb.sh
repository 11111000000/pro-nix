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
  # If credentials exist, use them
  if [ -f "/etc/samba/creds.d/$host" ]; then
    sudo $MOUNT_CIFS "//$hostfqdn/$share" "$mountpoint" -o credentials=/etc/samba/creds.d/$host,vers=3.0
    echo "Mounted //$hostfqdn/$share -> $mountpoint (credentials)"
    return 0
  fi

  # Interactive fallback: ask user for credentials and optionally save them
  echo "No credentials found for $host. You can enter them now (saved to /etc/samba/creds.d/$host with root:root, mode 600), or cancel." >&2
  read -p "Username (leave empty to cancel): " username
  if [ -z "$username" ]; then
    echo "Cancelled by user." >&2
    return 2
  fi
  # read -s hides password input
  read -s -p "Password: " password
  echo
  read -p "Save credentials to /etc/samba/creds.d/$host? [Y/n]: " saveans
  saveans=${saveans:-Y}
  if [[ "$saveans" =~ ^[Yy] ]]; then
    tmpf=$(mktemp)
    trap 'rm -f "$tmpf"' EXIT
    echo "username=$username" > "$tmpf"
    echo "password=$password" >> "$tmpf"
    # ask for domain optionally
    read -p "Domain/Workgroup (default WORKGROUP): " domain
    domain=${domain:-WORKGROUP}
    echo "domain=$domain" >> "$tmpf"
    echo "Saving credentials to /etc/samba/creds.d/$host (root:root, 600)"
    sudo mkdir -p /etc/samba/creds.d
    sudo mv "$tmpf" "/etc/samba/creds.d/$host"
    sudo chown root:root "/etc/samba/creds.d/$host"
    sudo chmod 600 "/etc/samba/creds.d/$host"
    trap - EXIT
  else
    # use a temporary credentials file for this mount attempt (no disk persistence)
    tmpf=$(mktemp)
    trap 'rm -f "$tmpf"' EXIT
    echo "username=$username" > "$tmpf"
    echo "password=$password" >> "$tmpf"
    echo "domain=${domain:-WORKGROUP}" >> "$tmpf"
  fi

  if sudo $MOUNT_CIFS "//$hostfqdn/$share" "$mountpoint" -o credentials="$tmpf",vers=3.0; then
    echo "Mounted //$hostfqdn/$share -> $mountpoint (interactive credentials)"
    trap - EXIT
    return 0
  else
    echo "Mount with provided credentials failed." >&2
    trap - EXIT
    return 3
  fi
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
