# Название: modules/pro-privacy.nix — Конфигурация приватных сетей (Tor, obfs4, Snowflake)
# Summary (EN): Tor and pluggable transports configuration for client anonymity
# Цель:
#   Обеспечить безопасные и проверяемые дефолты для Tor и вспомогательных
#   транспортив (obfs4, meek, snowflake). Комментарии объясняют, какие опции
#   влияют на boot/verify и почему некоторые файлы управляются вне декларативной
#   модели (bridges.conf).
# Контракт:
#   Опции: services.tor.client.enable, services.tor.bridges (list) — при
#           заполнении блочного списка будут сгенерированы Bridge строки.
#   Побочные эффекты: добавляет systemd.services.tor-ensure-bridges и
#   tor-ensure-perms; создаёт /etc/tor/bridges.conf.example.
# Предпосылки:
#   Требуются пакеты obfs4proxy, snowflake-client, meek-client в профиле при
#   использовании ClientTransportPlugin; некоторые опции могут требовать ядра
#   с поддержкой сетевых возможностей.
# Как проверить (Proof):
#   ./tools/holo-verify.sh unit (tests/contract/tor-01.sh)
# Last reviewed: 2026-05-03
{ config, pkgs, lib, ... }:

let
  helpers = {
    ensureBridges = pkgs.writeShellScriptBin "ensure-tor-bridges" ''
      #!/usr/bin/env bash
      set -euo pipefail
      mkdir -p /etc/tor
      if [ ! -e /etc/tor/bridges.conf ]; then
        cp /etc/tor/bridges.conf.example /etc/tor/bridges.conf
        chown root:root /etc/tor/bridges.conf
        chmod 0640 /etc/tor/bridges.conf
      fi
    '';

    ensurePerms = pkgs.writeShellScriptBin "ensure-tor-perms" ''
      #!/usr/bin/env bash
      set -euo pipefail
      mkdir -p /var/lib/tor
      chown -R tor:tor /var/lib/tor || true
      chmod 700 /var/lib/tor || true
      [ -d /var/lib/tor/ssh_hidden_service ] && chmod 700 /var/lib/tor/ssh_hidden_service || true
    '';
  };
in {

  options = {
    services.tor.enableSnowflake = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Compat: enable Snowflake helper service when set by host (legacy). Prefer module-level control via services.tor.enable.";
    };
  };

  config = {
  services.tor = {
    enable = true;
    client.enable = true;
    torsocks.enable = true;
    settings = {
      ControlPort = [ 9051 ];
      CookieAuthentication = true;
      ClientTransportPlugin = lib.mkForce [
        "obfs4 exec ${pkgs.obfs4}/bin/lyrebird"
        "meek exec ${pkgs.meek}/bin/meek-client"
        "snowflake exec ${pkgs.snowflake}/bin/client"
      ];
      DNSPort = [ 9053 ];
      AutomapHostsOnResolve = true;
      AutomapHostsSuffixes = [ ".onion" ".exit" ];
    };
  };

  # I2P — тяжёлый runtime-сервис. Общий privacy-модуль доставляет пакеты и
  # Tor-клиент, но не должен безусловно запускать I2P на каждом хосте.
  services.i2p.enable = lib.mkDefault false;

  environment.etc."tor/bridges.conf.example".source = ../conf/tor-bridges.conf;

  systemd.services."tor-ensure-bridges" = {
    description = "Ensure /etc/tor/bridges.conf exists (create from template)";
    wantedBy = [ "multi-user.target" ];
    before = [ "tor.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${helpers.ensureBridges}/bin/ensure-tor-bridges";
    };
  };

  systemd.services."tor-ensure-perms" = {
    description = "Ensure /var/lib/tor ownership and modes for Tor";
    before = [ "tor.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${helpers.ensurePerms}/bin/ensure-tor-perms";
    };
    wantedBy = [ "multi-user.target" ];
  };

  environment.systemPackages = with pkgs; [
    gawk
    obfs4
    meek
    snowflake
    tor
    torsocks
    tor-browser
    nyx
    onionshare
    i2p
    dnscrypt-proxy
    proxychains
    mullvad-vpn
    wireguard-tools
  ];

  networking.firewall = {
    allowedTCPPorts = [ 9050 9051 9052 9053 7657 4444 4445 ];
    allowedUDPPorts = [ 9564 ];
  };
};

}
