#!/usr/bin/env bash
# Сбор расширенной диагностики аудио (PipeWire/PulseAudio/ALSA) на NixOS.
# Запускать обычным пользователем.
set -euo pipefail

TS="$(date +%F-%H%M%S)"
OUTDIR="/tmp/audio-diag-${USER}-${TS}"
LOG="${OUTDIR}/summary.txt"
mkdir -p "${OUTDIR}"

log() { echo "== $*" | tee -a "${LOG}"; }
run() {
  local name="$1"; shift
  log "$name"
  {
    echo "---- ${name} ----"
    "$@" 2>&1 || true
    echo
  } | sed -e 's/\x1b\[[0-9;]*m//g' > "${OUTDIR}/$(echo "${name}" | tr ' /:' '___').txt"
}

# Базовая инфа
run "uname -a" uname -a
run "nixos-version" sh -lc 'command -v nixos-version && nixos-version || true'
run "systemd versions" sh -lc 'systemctl --version; loginctl --version'
run "user/groups" id
run "environment core vars" sh -lc 'env | egrep -i "^(XDG_|WAYLAND|DISPLAY|DBUS_|PULSE_|LANG|LC_|XAUTHORITY|PATH)=" | sort'
run "pam/logind sessions" sh -lc 'loginctl list-sessions; echo; loginctl session-status "$(loginctl show-user "$USER" -p Display --value 2>/dev/null || true)" || true'

# NixOS опции (если есть)
run "nixos-option: services.pipewire.*" sh -lc 'for o in services.pipewire.enable services.pipewire.pulse.enable services.pipewire.alsa.enable services.pipewire.alsa.support32Bit services.pulseaudio.enable security.rtkit.enable; do echo ">>> $o"; nixos-option "$o" || true; echo; done'

# Сервисы systemd --user
run "systemctl --user status pipewire services" sh -lc 'systemctl --user status pipewire.service pipewire-pulse.service wireplumber.service || true'
run "systemctl --user list running (audio)" sh -lc 'systemctl --user --no-pager --state=running --all | egrep -i "pipewire|wireplumber|pulse" || true'
run "systemctl --user cat units" sh -lc 'for u in pipewire.service wireplumber.service pipewire-pulse.service; do echo "===== $u ====="; systemctl --user cat "$u" || true; echo; done'

# Сокеты/рантайм
run "XDG_RUNTIME_DIR ownership" sh -lc 'ls -ld "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" 2>/dev/null || true'
run "/run/user/UID/pulse" sh -lc 'ls -l /run/user/$(id -u)/pulse 2>/dev/null || true'
run "pulse/pipewire unix sockets" sh -lc 'ss -xap | egrep -i "pulse|pipewire|pw" || true'

# Журналы
run "journalctl --user (pipewire/wireplumber/pulse) since boot" sh -lc 'journalctl --user -b -u pipewire -u wireplumber -u pipewire-pulse --no-pager || true'
run "system journal rtkit/pipewire since boot" sh -lc 'journalctl -b -t rtkit-daemon -u pipewire -u wireplumber --no-pager || true'

# PipeWire/WirePlumber
run "pipewire --version" sh -lc 'command -v pipewire && pipewire --version || true'
run "wpctl status" sh -lc 'command -v wpctl && wpctl status || true'
run "pw-cli list-objects" sh -lc 'command -v pw-cli && pw-cli list-objects || true'
run "pw-dump (JSON)" sh -lc 'command -v pw-dump && pw-dump > '"${OUTDIR}"'/pw-dump.json || true'
run "pw-top (1s)" sh -lc 'command -v pw-top && timeout 1 pw-top || true'

# Pulse (через pipewire-pulse)
run "pactl info" sh -lc 'command -v pactl && pactl info || true'
run "pactl list short sinks/sources/clients" sh -lc 'command -v pactl && { pactl list short sinks; echo; pactl list short sources; echo; pactl list short clients; } || true'

# ALSA и устройства
run "aplay -l" sh -lc 'command -v aplay && aplay -l || true'
run "arecord -l" sh -lc 'command -v arecord && arecord -l || true'
run "/proc/asound/cards" sh -lc 'cat /proc/asound/cards 2>/dev/null || true'
run "/proc/asound/modules" sh -lc 'cat /proc/asound/modules 2>/dev/null || true'
run "/dev/snd permissions" sh -lc 'ls -l /dev/snd 2>/dev/null || true'
run "lsmod (sound)" sh -lc 'lsmod | egrep "^snd|^sound|^sof|hda|snd_hda|snd_sof|snd_usb" || true'
run "lspci -nnk | audio" sh -lc 'command -v lspci && lspci -nnk | grep -iA3 audio || true'
run "dmesg (audio-related)" sh -lc 'dmesg -T | egrep -i "snd|hda|sof|audio|alsa|pcm|pinctrl|no response|firmware" | tail -n 500 || true'
run "udev (sound cards)" sh -lc 'for c in /sys/class/sound/card* 2>/dev/null; do echo ">>> $c"; udevadm info -q all -p "$c" 2>/dev/null || true; echo; done'

# DBus (user)
run "DBus (user) services (audio)" sh -lc 'command -v busctl && busctl --user list | egrep -i "wireplumber|pipewire|pulse" || true'

# Краткий вывод
SUMMARY="${OUTDIR}/quick-findings.txt"
{
  echo "Quick findings:"
  PWS=$(systemctl --user is-active pipewire.service 2>/dev/null || true)
  PWPS=$(systemctl --user is-active pipewire-pulse.service 2>/dev/null || true)
  WPS=$(systemctl --user is-active wireplumber.service 2>/dev/null || true)
  echo "- pipewire:        ${PWS:-unknown}"
  echo "- pipewire-pulse:  ${PWPS:-unknown}"
  echo "- wireplumber:     ${WPS:-unknown}"
  test -S "/run/user/$(id -u)/pulse/native" && echo "- pulse socket:    OK" || echo "- pulse socket:    MISSING"
  echo "- XDG_RUNTIME_DIR: ${XDG_RUNTIME_DIR:-unset}"
  if [ -d /dev/snd ]; then
    echo "- /dev/snd exists: yes"
  else
    echo "- /dev/snd exists: no (ядро не создало устройства ALSA)"
  fi
} > "${SUMMARY}"

# Архив
TARBALL="/tmp/audio-diag-${USER}-${TS}.tar.gz"
tar -C "${OUTDIR%/*}" -czf "${TARBALL}" "$(basename "${OUTDIR}")"
echo "Диагностика собрана: ${TARBALL}"
echo "Краткое резюме: ${SUMMARY}"
echo "Полные логи: ${OUTDIR}"
