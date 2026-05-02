#!/usr/bin/env bash
set -euo pipefail

# Лог-файл по умолчанию: analyse.log (можно передать свой путь первым аргументом)
LOGFILE="${1:-analyse.log}"
# Очищаем лог и включаем tee: вывод виден на экране и пишется в файл
: > "$LOGFILE"
exec > >(tee -a "$LOGFILE") 2>&1

hr() { printf "\n%s\n" "────────────────────────────────────────────────────────"; }
sec() { hr; printf "%s\n" "$1"; hr; }

run() {
  local title="$1"; shift
  sec "$title"
  # Печатаем команду и её вывод (stdout+stderr)
  printf "CMD: %s\n" "$*"
  { "$@" 2>&1 || true; } | sed 's/^/  /'
}

# Шапка запуска
sec "0) Контекст запуска"
echo "Дата/время:    $(date -Is)"
echo "Пользователь:  $(id -un) (uid=$(id -u))"
echo "Хост:          $(hostname)"
echo "Каталог:       $PWD"
echo "Boot ID:       $(cat /proc/sys/kernel/random/boot_id 2>/dev/null || echo n/a)"

# 1) Версии системы и каналов
sec "1) Версии: NixOS/Nix/nixpkgs, ядро"
echo "CMD: nixos-version"
{ nixos-version 2>&1 || true; } | sed 's/^/  /'
echo
echo "CMD: nix --version"
{ nix --version 2>&1 || true; } | sed 's/^/  /'
echo
echo "CMD: uname -srvmo"
{ uname -srvmo 2>&1 || true; } | sed 's/^/  /'
echo
# Версия nixpkgs из канала <nixpkgs> (если есть) или через flakes
echo "CMD: nix-instantiate --eval -E 'with import <nixpkgs> {}; lib.version'"
{ nix-instantiate --eval -E 'with import <nixpkgs> {}; lib.version' 2>&1 || true; } | sed 's/^/  /'
echo
echo "CMD: nix eval nixpkgs#lib.version (flakes)"
{ nix eval nixpkgs#lib.version 2>&1 || true; } | sed 's/^/  /'
echo
# Версия unstable, если подключен <nixos-unstable>
echo "CMD: nix-instantiate --eval -E 'with import <nixos-unstable> {}; lib.version'"
{ nix-instantiate --eval -E 'with import <nixos-unstable> {}; lib.version' 2>&1 || true; } | sed 's/^/  /'

# 2) Ключевые опции NixOS (audit/auditd, firewall, tor, DM/startx, XKB и т.д.)
sec "2) Выдержка по ключевым опциям NixOS (nixos-option)"
for opt in \
  system.stateVersion \
  services.xserver.enable \
  services.xserver.displayManager.gdm.enable \
  services.xserver.displayManager.startx.enable \
  services.displayManager.autoLogin \
  services.xserver.displayManager.autoLogin \
  services.xserver.windowManager.session \
  services.logind.extraConfig \
  services.gnome.gnome-keyring.enable \
  security.pam.services.login.enableGnomeKeyring \
  services.pipewire.enable \
  services.pulseaudio.enable \
  security.rtkit.enable \
  services.printing.enable \
  services.avahi.enable \
  services.tor.enable \
  services.tor.openFirewall \
  services.tor.client.enable \
  services.syncthing.enable \
  services.syncthing.openDefaultPorts \
  services.guix.enable \
  services.udisks2.enable \
  virtualisation.docker.enable \
  networking.networkmanager.enable \
  services.resolved.enable \
  networking.firewall.enable \
  networking.firewall.allowedTCPPorts \
  networking.firewall.allowedUDPPorts \
  services.xserver.xkb.layout \
  services.xserver.xkb.options \
  console.useXkbConfig \
  console.earlySetup \
  console.font \
  zramSwap.enable \
  security.audit.enable \
  security.auditd.enable \
  security.auditd.extraRules \
  security.apparmor.enable \
  programs.firefox.enable \
; do
  echo
  echo "nixos-option $opt"
  { nixos-option "$opt" 2>&1 || true; } | sed 's/^/  /'
done

# 3) Клавиатура/раскладки и консоль
sec "3) Ввод: XKB и vconsole"
run "localectl status" localectl status
run "setxkbmap -query (если X запущен)" setxkbmap -query
run "Содержимое /etc/vconsole.conf" cat /etc/vconsole.conf
run "Журнал systemd-vconsole-setup (последняя загрузка)" journalctl -b -u systemd-vconsole-setup --no-pager -n 50

# 6) Переменные окружения (GTK/Qt/IM), для текущей shell-сессии
sec "6) Переменные окружения (GTK/Qt/IM) из текущей сессии"
{ printenv | egrep '^(LANG|LC_CTYPE|GTK_KEY_THEME|QT_QPA_PLATFORMTHEME|QT_STYLE_OVERRIDE|XMODIFIERS|GTK_IM_MODULE|QT_IM_MODULE|CLUTTER_IM_MODULE)=' 2>/dev/null || true; } | sed 's/^/  /'
echo
echo "Переменные окружения в systemd --user (если X-сессия уже экспортировала их):"
{ systemctl --user show-environment 2>/dev/null | egrep '^(DISPLAY|XAUTHORITY|LANG|GTK_KEY_THEME|QT_QPA_PLATFORMTHEME|QT_STYLE_OVERRIDE|XMODIFIERS|GTK_IM_MODULE|QT_IM_MODULE|CLUTTER_IM_MODULE)=' || true; } | sed 's/^/  /'

# 7) Статусы служб
sec "7) Статусы ключевых служб (systemd is-enabled/is-active)"
services=(NetworkManager bluetooth systemd-resolved auditd fail2ban tor docker udisks2 pipewire pipewire-pulse syncthing@az)
for s in "${services[@]}"; do
  ie=$(systemctl is-enabled "$s" 2>/dev/null || true)
  ia=$(systemctl is-active  "$s" 2>/dev/null || true)
  printf "  %-20s enabled=%-10s active=%s\n" "$s" "${ie:-n/a}" "${ia:-n/a}"
done

# 8) Tor/CUPS/Avahi — потенциальные дубли firewall
sec "8) Проверка портов и служб (Tor/CUPS/Avahi)"
run "ss -ltnp (TCP listen)" ss -ltnp
run "ss -lunp (UDP listen)" ss -lunp

# 9) Swap и гибернация (resume)
sec "9) Swap и параметры ядра для resume"
run "swapon --show" swapon --show
run "cat /proc/cmdline" cat /proc/cmdline

# 13) Диагностика последней загрузки (systemd/journal)
sec "13) Диагностика последней загрузки"
run "systemd-analyze time" systemd-analyze time
run "systemd-analyze blame (топ-30 самых «долгих» юнитов)" bash -lc 'systemd-analyze blame | head -n 30'
run "systemd-analyze critical-chain" systemd-analyze critical-chain
run "Список неуспешных юнитов (systemctl --failed)" systemctl --failed
run "Ошибки журнала (journalctl -b -0 -p err)" journalctl -b -0 -p err --no-pager -n 200
run "Предупреждения журнала (journalctl -b -0 -p warning)" journalctl -b -0 -p warning --no-pager -n 200
run "dmesg: уровни err,warn (последние 200 строк)" bash -lc 'dmesg --color=never -T --level=err,warn 2>/dev/null | tail -n 200 || true'
run "Список загрузок (последние 5) — journalctl --list-boots" bash -lc 'journalctl --list-boots | tail -n 5'

echo
echo "Готово. Весь вывод записан в: $LOGFILE"
echo "Поделитесь файлом $LOGFILE в обсуждении/issue для точечных правок."
