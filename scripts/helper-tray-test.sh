#!/usr/bin/env bash
# Diagnose EXWM system tray and applets
# Usage: exwm-tray-diagnose.sh [--no-logs]
set -euo pipefail

NO_LOGS=0
if [[ "${1-}" == "--no-logs" ]]; then
  NO_LOGS=1
fi

header() {
  echo
  echo "==== $* ===="
}

has() { command -v "$1" >/dev/null 2>&1; }

SERVICES=(
  nm-applet
  blueman-applet
  copyq
  udiskie-tray
  dunst
  pasystray
  snixembed
  xset-dpms-off
  polkit-gnome-authentication-agent-1
)

header "Basic environment"
echo "USER: $USER"
echo "DISPLAY: ${DISPLAY-<unset>}"
echo "XAUTHORITY: ${XAUTHORITY-<unset>}"
echo "XDG_RUNTIME_DIR: ${XDG_RUNTIME_DIR-<unset>}"
echo "XDG_CURRENT_DESKTOP: ${XDG_CURRENT_DESKTOP-<unset>}"
echo "DBUS_SESSION_BUS_ADDRESS: ${DBUS_SESSION_BUS_ADDRESS-<unset>}"

header "systemd --user environment (show-environment)"
if has systemctl; then
  systemctl --user show-environment | grep -E '^(DISPLAY|XAUTHORITY|XDG_CURRENT_DESKTOP|DBUS_SESSION_BUS_ADDRESS)=' || true
else
  echo "systemctl not found"
fi

header "systemd --user: targets and dbus"
if has systemctl; then
  systemctl --user is-active dbus.service || true
  systemctl --user status exwm-session.target --no-pager || true
  echo
  echo "exwm-session.target dependencies:"
  systemctl --user list-dependencies --plain exwm-session.target || true
  echo
  echo "~/.config/systemd/user/exwm-session.target.wants:"
  ls -l ~/.config/systemd/user/exwm-session.target.wants || true
else
  echo "systemctl not found"
fi

header "Check for other tray hosts (may conflict)"
if has pgrep; then
  pgrep -fa -l 'trayer|stalonetray|tint2|polybar|lxqt-panel|mate-panel|xfce4-panel' || echo "No known conflicting tray hosts found"
else
  echo "pgrep not found"
fi

header "X11: system tray selection owner (_NET_SYSTEM_TRAY_S0)"
if has xprop; then
  if xprop -root _NET_SYSTEM_TRAY_S0 >/dev/null 2>&1; then
    xprop -root _NET_SYSTEM_TRAY_S0
    OWNER_HEX=$(xprop -root _NET_SYSTEM_TRAY_S0 | awk -F'# ' '/_NET_SYSTEM_TRAY_S0/ {print $2}')
    if [[ -n "${OWNER_HEX}" ]]; then
      echo
      echo "Selection owner window (${OWNER_HEX}) name:"
      xprop -id "${OWNER_HEX}" _NET_WM_NAME 2>/dev/null || true
    fi
  else
    echo "_NET_SYSTEM_TRAY_S0: not present (no tray host has the selection)"
  fi
else
  echo "xprop not found"
fi

header "X11: look for EXWM tray windows"
if has xwininfo; then
  xwininfo -root -tree | grep -i 'exwm-systemtray' || echo "No exwm-systemtray windows found in tree"
else
  echo "xwininfo not found"
fi

header "D-Bus (user bus): StatusNotifier watcher and items"
if has busctl; then
  echo "- Is user dbus active?"
  systemctl --user is-active dbus.service || true
  echo
  echo "- Bus names of interest:"
  busctl --user --no-pager list | awk '{print $1}' | grep -E 'org\.kde\.StatusNotifierWatcher|org\.kde\.StatusNotifierItem' || echo "No StatusNotifier watcher/items detected"
  echo
  echo "- snixembed on the bus?"
  busctl --user --no-pager list | awk '{print $1}' | grep -E 'snixembed' || echo "snixembed name not seen (it may not own a bus name, check its logs below)"
else
  echo "busctl not found; skipping D-Bus checks"
fi

header "Processes (applets and bridge)"
if has pgrep; then
  for p in nm-applet blueman-applet copyq udiskie dunst pasystray snixembed xembedsniproxy; do
    echo "pgrep -fa ${p}:"
    pgrep -fa "${p}" || echo "  not running"
    echo
  done
else
  echo "pgrep not found"
fi

header "systemd --user services: active/enabled + ExecStart/Env"
if has systemctl; then
  for s in "${SERVICES[@]}"; do
    echo ">>> ${s}.service"
    systemctl --user is-enabled "${s}.service" 2>&1 || true
    systemctl --user is-active  "${s}.service" 2>&1 || true
    systemctl --user show -p ExecStart -p Environment "${s}.service" | sed 's/^/  /'
    echo
  done
else
  echo "systemctl not found"
fi

if [[ $NO_LOGS -eq 0 ]]; then
  header "Recent logs (journalctl --user -n 50) for key services"
  if has journalctl; then
    for s in snixembed nm-applet blueman-applet copyq udiskie-tray dunst pasystray; do
      echo "----- ${s}.service -----"
      journalctl --user -u "${s}.service" -n 50 --no-pager || true
      echo
    done
  else
    echo "journalctl not found"
  fi
else
  echo "Skipping logs (requested by --no-logs)"
fi

header "Hints"
cat <<'HINTS'
- If _NET_SYSTEM_TRAY_S0 has no owner: ensure Emacs has exwm-systemtray-mode enabled.
  M-: (bound-and-true-p exwm-systemtray-mode)
- If snixembed is inactive: systemctl --user restart snixembed.service
- If applets are inactive: systemctl --user restart exwm-session.target
- If D-Bus user bus is inactive: systemctl --user start dbus.service
- If there is another tray host (trayer/tint2/etc.), stop it so EXWM can own the tray.
HINTS
