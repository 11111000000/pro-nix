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
      # NB: дефолт ссылается на публичную Tailscale-карту — это снимает
      # ошибку "initial DERPMap is empty" в случае, если встроенный DERP
      # отключён (см. ниже). Если встроенный сервер включён, headscale
      # предпочитает локальный DERP; публичный используется как fallback.
      default = [ "https://controlplane.tailscale.com/derpmap/default" ];
      example = [ "https://control.pro-nix.lan/derp" ];
      description = ''
        DERP map URLs. Empty means "use only the embedded DERP server"
        (requires `derpServer = true`). When set, clients use these
        URLs in addition to (or instead of) the embedded server.
      '';
    };
    derpServer = lib.mkOption {
      type = lib.types.bool;
      # Default: ON. Без DERP headscale 0.27+ стартует с FTL "initial
      # DERPMap is empty, Headscale requires at least one entry".
      # Встроенный DERP-сервер поднимается на 0.0.0.0:80 (TCP) +
      # 0.0.0.0:3478 (STUN/UDP). Для продакшна с собственным FQDN
      # ставьте `derpServer = false` и `derpUrls = [ "https://..." ]`.
      default = true;
      description = ''
        Run the embedded DERP relay server on this host. Required unless
        `derpUrls` points at an externally-hosted DERP map. DERP serves
        WireGuard relay traffic when direct P2P fails (NAT, firewalls).
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

    # Firewall: открыть STUN (3478/udp) и DERP-HTTP (80/tcp) при
    # встроенном DERP-сервере. 80/tcp — это тот же порт, что в `derp.server.urls`
    # по умолчанию. Если меняете на 443 (за reverse-proxy) — обновите
    # allowedTCPPorts и stun_listen_addr соответственно.
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.derpServer [ 80 ];
    networking.firewall.allowedUDPPorts = lib.mkIf cfg.derpServer [ 3478 ];

    # Generate config via `pkgs.formats.yaml` so list/boolean values are
    # rendered correctly. Hand-rolled `lib.concatStringsSep "," (map ...
    # "\"${s}\"")` produced `"1.1.1.1","8.8.8.8"` — a single string, not
    # a YAML list, which headscale rejects with a parse error.
    environment.etc."headscale/config.yaml".source =
      let
        yamlFormat = pkgs.formats.yaml {};
        # DERP-блок рендерим ВСЕГДА (с urls и/или server.enabled). В headscale
        # 0.27+ пустой `derp:` без urls и с выключенным server приводит к
        # FTL "initial DERPMap is empty". Если оба источника выключены —
        # это явная ошибка конфигурации, сервер всё равно упадёт, что и
        # хочется (loud failure лучше тихого).
        derpBlock = {
          derp = {
            urls = cfg.derpUrls;
            server = {
              enabled = cfg.derpServer;
              region_id = 999;
              stun_listen_addr = "0.0.0.0:3478";
              # В headscale 0.27+ DERP-server требует свой private key.
              # Без явного пути headscale стартует с пустым путём и падает:
              # "failed to read or create DERP server private key: open : no such file".
              private_key_path = "/var/lib/headscale/derp_server_private.key";
            };
          };
        };
      in yamlFormat.generate "headscale-config.yaml" ({
        server_url = "http://0.0.0.0:8080";
        listen = cfg.listenAddress;
        metrics_listen = "0.0.0.0:9090";
        # In headscale 0.27+ the database settings moved under a
        # `database:` mapping (`type` + `sqlite.path` or `postgres.*`).
        # The flat `db_type` / `db_path` keys are still parsed but
        # ignored by the server.
        database = {
          type = "sqlite3";
          sqlite.path = "/var/lib/headscale/headscale.db";
        };
        private_key_path = "/var/lib/headscale/private.key";
        noise.private_key_path = "/var/lib/headscale/noise_private.key";
        # In headscale 0.27+ the IP prefix settings moved under a
        # `prefixes:` mapping (previously `prefix_v4` / `prefix_v6`).
        # The old keys are still accepted by the parser but are no longer
        # used by the server, so we have to spell out the new shape.
        prefixes = {
          v4 = "100.64.0.0/10";
          v6 = "fd7a:115c:a1e0::/48";
        };
        base_domain = cfg.baseDomain;
        dns = {
          base_domain = cfg.baseDomain;
          nameservers.global = cfg.nameservers;
          extra_records_path = "/var/lib/headscale/extra-records.json";
          magic_dns = true;
        };
      } // derpBlock);

    systemd.tmpfiles.rules = [
      "d /var/lib/headscale 0755 root root -"
      # Pre-create empty extra-records.json so Headscale starts even before
      # the operator has populated it.
      "f /var/lib/headscale/extra-records.json 0644 root root - []"
    ];
  };
}
