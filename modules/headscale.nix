# Название: modules/headscale.nix — Headscale (control plane для WireGuard)
# Кратко: модуль включает headscale как контроллер mesh-сети WireGuard, создаёт
# systemd unit и минимальную конфигурацию; оператор должен обеспечить безопасную
# конфигурацию в overlay на уровне хоста.
#
# Цель:
#   Обеспечить воспроизводимую, native-интеграцию headscale с systemd и системой
#   пакетов Nix. Модуль не заменяет operator-managed конги; он предоставляет
#   разумные деолты и инструкции для override.
#
# Контракт:
#   Опции: config.headscale.enable, config.headscale.listenAddress,
#          config.headscale.baseDomain, config.headscale.derpUrls,
#          config.headscale.nameservers.
#   Побочные эффекты: создаёт systemd.services.headscale; записывает
#     /etc/headscale/config.yaml с примерами (оператор должен заменить в
#     host overlay, если нужно).
#
# Предпосылки:
#   Требуется пакет headscale; по-умолчанию слушает 0.0.0.0:8080 — оператору следует
#   настроить firewall/адресацию при необходимости.
#
# Как проверить (Proof):
#   `systemctl status headscale`; `curl http://localhost:8080/health`.
#
# Last reviewed: 2026-05-03
{ config, pkgs, lib, ... }:

let
  cfg = config.headscale;
in

{
  options.headscale = {
    enable = lib.mkEnableOption "Enable Headscale service (control plane for WireGuard)";
    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0:8080";
      description = "Address Headscale listens on";
    };
    baseDomain = lib.mkOption {
      type = lib.types.str;
      default = "pro-nix.ts.net";
      description = ''
        Base domain advertised by the embedded DNS server. Each node gets
        `<shortname>.<baseDomain>`. Must match the tailscale `loginServer`
        configured on the client side.
      '';
    };
    nameservers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "1.1.1.1"
        "8.8.8.8"
        "2606:4700:4700::1111"
      ];
      description = "Upstream resolvers advertised via MagicDNS to clients.";
    };
    derpUrls = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = [ "https://control.pro-nix.lan/derp" ];
      description = ''
        Optional DERP map URLs. When set, clients prefer the embedded DERP
        server (run separately) before falling back to the public Tailscale
        DERP map.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Ensure headscale package is always present when this module is enabled.
    environment.systemPackages = with pkgs; [ headscale ];

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
      listen: "${cfg.listenAddress}"
      metrics_listen: "0.0.0.0:9090"
      db_type: "sqlite3"
      db_path: "/var/lib/headscale/headscale.db"
      private_key_path: "/var/lib/headscale/private.key"
      noise:
        private_key_path: "/var/lib/headscale/noise_private.key"
      prefix_v4: "100.64.0.0/10"
      prefix_v6: "fd7a:115c:a1e0::/48"
      base_domain: "${cfg.baseDomain}"
      dns:
        base_domain: "${cfg.baseDomain}"
        nameservers.global: ${lib.concatStringsSep "," (map (s: "\"${s}\"") cfg.nameservers)}
        extra_records_path: "/var/lib/headscale/extra-records.json"
        magic_dns: true
        use_username_in_magic_dns: false
      ${lib.optionalString (cfg.derpUrls != []) "derp:"}
      ${lib.optionalString (cfg.derpUrls != "") (lib.concatMapStringsSep "\n" (u: "  urls:\n    - \"${u}\"") cfg.derpUrls)}
      # DERP embedded server is opt-in: only enable on hosts that explicitly
      # need it (otherwise rely on a separate DERP instance or the public map).
      derp.server:
        enabled: false
        region_id: 999
        stun_listen_addr: "0.0.0.0:3478"
    '';

    systemd.tmpfiles.rules = [
      "d /var/lib/headscale 0755 root root -"
      # Pre-create empty extra-records.json so Headscale starts even before
      # the operator has populated it.
      "f /var/lib/headscale/extra-records.json 0644 root root - []"
    ];
  };
}
