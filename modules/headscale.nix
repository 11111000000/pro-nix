# Название: modules/headscale.nix — Headscale control plane для WireGuard
# Summary (EN): Headscale service (WireGuard-based VPN control plane)
/* RU: Headscale — контроллер для WireGuard-подобного control-plane. Модуль настраивает
   systemd unit, необходимые пакеты и зависимости. Контракт модуля описывает опции,
   эффекты на сеть и проверки для healthcheck.
*/
# Цель:
#   Включить Headscale как control plane для WireGuard VPN. Позволяет
#   управлять mesh-сетью хостов через единый сервис.
# Контракт:
#   Опции: config.headscale.enable, config.headscale.listenAddress
#   Побочные эффекты: создаёт systemd.services.headscale; пишет /etc/headscale/config.yaml.
# Предпосылки:
#   Требуется пакет headscale; для работы нужен внешний интерфейс на порту 8080.
# Как проверить (Proof):
#   `systemctl status headscale`, `curl http://localhost:8080/health`
# Last reviewed: 2026-04-25
# Файл: автосгенерированная шапка — комментарии рефакторятся
{ config, pkgs, lib, ... }:

/* RU: Файловый контракт — Headscale module
   Контракт:
   - Цель: обеспечить native Headscale service как control plane для WireGuard.
   - Контракт опций: headscale.enable, headscale.listenAddress.
   - Побочные эффекты: systemd service, конфигурационные файлы в /etc/headscale.
   - Proof: systemctl status headscale; curl health endpoint.
   - Last reviewed: 2026-05-02
*/

let
  cfg = {};
in

{
  options = {
    headscale = {
      enable = lib.mkEnableOption "Enable Headscale service (control plane for WireGuard)";
      listenAddress = lib.mkOption {
        type = lib.types.str;
        default = "0.0.0.0:8080";
        description = "Address Headscale listens on";
      };
    };
  };

  config = lib.mkIf config.headscale.enable {
    # Prefer native headscale package over docker by default. Add as a low-
    # priority contribution so top-level aggregation decides final list.
    environment.systemPackages = lib.mkDefault (with pkgs; [ headscale ]);

    # Minimal native systemd service. Operator should override config.yaml in host overlay.
    systemd.services.headscale = {
      description = "Headscale (WireGuard control plane)";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.headscale}/bin/headscale serve --config /etc/headscale/config.yaml";
        Restart = "on-failure";
        PrivateTmp = "true";
      };
    };

    environment.etc."headscale/config.yaml".text = ''
    # Minimal headscale config. Operator: override in host overlay at /etc/headscale/config.yaml
    server_url: "http://0.0.0.0:8080"
    listen: "0.0.0.0:8080"
    db_type: "sqlite3"
    db_path: "/var/lib/headscale/headscale.db"
    '';

    systemd.tmpfiles.rules = [ "d /var/lib/headscale 0755 root root -" ];
  };
}
