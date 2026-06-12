# Название: modules/pro-wifi-watchdog.nix — Proactive WiFi link watchdog
# Кратко: периодически проверяет реальную связность и просит NM
#   переассоциироваться раньше, чем пользователь заметит лаг.
#
# Цель:
#   NetworkManager не дёргает radio, пока не получит deauth от AP или
#   пока не истечёт connection-timeout (по умолчанию ~30-60с). На ноутбуках
#   с шумным эфиром (cf19 + Android hotspot — см.
#   docs/analyse/2026-06-02-network-drops-cf19.md) это значит, что после
#   микро-разрыва NM "висит" с dead link секундами-минутами, пока AP
#   не пришлёт явный deauth.
#
#   Этот watchdog — ПРЕВЕНТИВНАЯ мера: каждые 60с пингует 1.1.1.1, и если
#   связности нет, вызывает `nmcli connection up` для активного WiFi-профиля.
#   NM реассоциирует за 1-3с, юзер не успевает почувствовать разрыв.
#
# Контракт:
#   Включается автоматически при наличии NetworkManager.
#   Опции:
#     pro.wifi.watchdog.enable   — bool (default true).
#     pro.wifi.watchdog.interval — str, default "60s".
#     pro.wifi.watchdog.target   — str, ping target (default "1.1.1.1").
#   Побочные эффекты: добавляет systemd unit + timer.
#
# Как проверить (Proof):
#   systemctl list-timers pro-wifi-watchdog
#   journalctl -u pro-wifi-watchdog.service -n 20
#
# Last reviewed: 2026-06-13
{ config, lib, pkgs, ... }:

let
  inherit (lib) mkOption mkEnableOption types;

  cfg = config.pro.wifi.watchdog;
  nmEnabled = config.networking.networkmanager.enable;

  # Скрипт собирается через writeShellScriptBin — тот же паттерн, что и
  # ops-wifi-recover в hosts/cf19/configuration.nix.
  watchdogScript = pkgs.writeShellScriptBin "pro-wifi-watchdog" ''
    set -euo pipefail
    if ! ${pkgs.iputils}/bin/ping -c 2 -W 3 "${cfg.target}" >/dev/null 2>&1; then
      # Связности нет — пробуем переассоциировать активное WiFi-соединение.
      # || true: nmcli может вернуть non-zero если профиль уже поднимается;
      # это не ошибка для таймера — NM сам доделает.
      nm=$(${pkgs.networkmanager}/bin/nmcli -t -f NAME,TYPE connection show --active 2>/dev/null \
           | awk -F: '$2=="wifi"{print $1; exit}')
      if [ -n "$nm" ]; then
        ${pkgs.networkmanager}/bin/nmcli connection up "$nm" || true
      fi
    fi
  '';
in
{
  options.pro.wifi.watchdog = {
    enable = mkEnableOption "Proactive WiFi link watchdog (ping + nmcli reassociate)" // { default = true; };
    interval = mkOption {
      type = types.str;
      default = "60s";
      description = "Systemd timer OnUnitActiveSec — как часто проверять связность.";
    };
    target = mkOption {
      type = types.str;
      default = "1.1.1.1";
      description = "ICMP-target для проверки реальной интернет-связности.";
    };
  };

  config = lib.mkIf (cfg.enable && nmEnabled) {
    systemd.services.pro-wifi-watchdog = {
      description = "Proactive WiFi link watchdog: reassociate on connectivity loss";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" "NetworkManager.service" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${watchdogScript}/bin/pro-wifi-watchdog";
        Restart = "on-failure";
        RestartSec = "30s";
      };
    };
    systemd.timers.pro-wifi-watchdog = {
      description = "Periodic WiFi link check";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "2min";
        OnUnitActiveSec = cfg.interval;
        RandomizedDelaySec = "5s";
        AccuracySec = "1s";
      };
    };
  };
}
