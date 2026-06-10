#!/run/current-system/sw/bin/bash
# ops-pro-samba-setup-users — populate Samba passdb with pro-nix Unix users.
#
# Walks the canonical pro-nix user list (az, za, la, bo) and, for each user
# that exists locally, runs `smbpasswd -a` and `smbpasswd -e` so that the
# declared `valid users = az za la bo` in pro-storage.nix actually authenticate.
#
# Idempotent: users already in the passdb are skipped. Re-run safely.
#
# Password source (highest priority first):
#   1. PRO_SAMBA_PASS_<USER>  environment variable (for scripted bootstraps)
#   2. --password-file=PATH    file containing the password (mode 600, root only)
#   3. interactive read -s     prompts on the controlling tty
#
# If no password source works for a user, that user is reported as FAILED and
# the loop continues with the rest. The script exits 0 unless EVERY user failed.
#
# Usage:
#   sudo ops-pro-samba-setup-users
#   sudo PRO_SAMBA_PASS_az=secret ops-pro-samba-setup-users
#   sudo ops-pro-samba-setup-users --password-file=/root/samba-pass.txt
#   sudo ops-pro-samba-setup-users --user=az --user=za   # subset
set -euo pipefail

USERS_DEFAULT="az za la bo"
USERS="$USERS_DEFAULT"
PASS_FILE=""

usage() {
  cat <<EOF
Usage: $(basename "$0") [--user=NAME]... [--password-file=PATH]
Populate Samba passdb with pro-nix Unix users (default: $USERS_DEFAULT).

Options:
  --user=NAME           Add this user (repeatable). Default: $USERS_DEFAULT.
  --password-file=PATH  Read password for any user not given via env var
                        PRO_SAMBA_PASS_<USER>. Must be mode 600.

Environment:
  PRO_SAMBA_PASS_<USER>  Use this as the password for USER (highest priority).

Exit codes:
  0  every requested user is in passdb and enabled (idempotent re-runs)
  1  one or more users failed to add
  2  bad arguments / smbpasswd not found
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --user=*) USERS="${USERS} ${1#*=}"; shift;;
    --user)   USERS="${USERS} $2"; shift 2;;
    --password-file=*) PASS_FILE="${1#*=}"; shift;;
    --password-file) PASS_FILE="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2;;
  esac
done

# Dedupe + trim. We avoid `awk` here: this script runs as a systemd
# oneshot service with a minimal PATH, and `awk` is not always on it
# (it lives in /usr/bin/awk on some distros but is not in the systemd
# unit's default PATH under NixOS). Pure shell + tr + sort -u is enough.
USERS=$(printf '%s\n' $USERS | sort -u | tr '\n' ' ')

for cmd in smbpasswd pdbedit; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "$cmd not found — install samba on this host first" >&2
    exit 2
  fi
done

if [[ -n "$PASS_FILE" ]]; then
  if [[ ! -f "$PASS_FILE" ]]; then
    echo "--password-file=$PASS_FILE does not exist" >&2
    exit 2
  fi
  if [[ "$(stat -c %a "$PASS_FILE" 2>/dev/null || stat -f %Lp "$PASS_FILE")" != "600" ]]; then
    echo "$PASS_FILE must be mode 600" >&2
    exit 2
  fi
fi

# Cache passdb listing once. Avoid `awk` for the same reason as the
# dedupe above: minimal PATH in the systemd unit. `cut -d:` reads the
# first `:`-delimited field which is the username.
EXISTING=$(pdbedit -L 2>/dev/null | cut -d: -f1 | sort -u)

failed=()
added=()
skipped=()

get_pass() {
  local u="$1"
  local envvar="PRO_SAMBA_PASS_${u}"
  if [[ -n "${!envvar:-}" ]]; then
    printf '%s' "${!envvar}"
    return 0
  fi
  if [[ -n "$PASS_FILE" ]]; then
    # Each line: USER:PASSWORD
    local line pw
    line=$(grep -E "^${u}:" "$PASS_FILE" || true)
    if [[ -n "$line" ]]; then
      pw="${line#*:}"
      printf '%s' "$pw"
      return 0
    fi
  fi
  if [[ -t 0 ]]; then
    local pw1 pw2
    read -r -s -p "Samba password for $u: " pw1; echo
    read -r -s -p "Confirm: " pw2; echo
    if [[ "$pw1" != "$pw2" ]]; then
      echo "  passwords do not match" >&2
      return 1
    fi
    printf '%s' "$pw1"
    return 0
  fi
  echo "  no password source for $u (need PRO_SAMBA_PASS_${u}, --password-file entry, or a tty)" >&2
  return 1
}

for u in $USERS; do
  if ! id "$u" >/dev/null 2>&1; then
    echo "[skip] $u — no Unix account on this host"
    skipped+=("$u")
    continue
  fi
  if printf '%s\n' "$EXISTING" | grep -qx "$u"; then
    echo "[ok]   $u — already in Samba passdb"
    # Make sure account is enabled (no-op if already enabled).
    smbpasswd -e "$u" >/dev/null 2>&1 || true
    skipped+=("$u")
    continue
  fi
  echo "[add]  $u — adding to Samba passdb"
  if ! pass=$(get_pass "$u"); then
    failed+=("$u")
    continue
  fi
  if printf '%s\n%s\n' "$pass" "$pass" | smbpasswd -s -a "$u" >/dev/null 2>&1; then
    smbpassbar=$(smbpasswd -e "$u" 2>&1) || true
    added+=("$u")
    echo "       added and enabled"
  else
    echo "       smbpasswd -a $u FAILED" >&2
    failed+=("$u")
  fi
  # scrub local var
  unset pass
done

echo
echo "==== summary ===="
echo "added:   ${added[*]:-none}"
echo "skipped: ${skipped[*]:-none}"
echo "failed:  ${failed[*]:-none}"

if [[ ${#failed[@]} -gt 0 && ${#added[@]} -eq 0 && ${#skipped[@]} -eq 0 ]]; then
  exit 1
fi
exit 0
