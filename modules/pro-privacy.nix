# Файл: автосгенерированная шапка — комментарии рефакторятся
{ pkgs, lib, ... }:

{
  # Раздел: приватность и анонимные сети — учебное объяснение
  #
  # Суть раздела:
  # Приводится конфигурация клиентских средств приватности: Tor и сопутствующие
  # транспорты (obfs4, snowflake, meek). Комментарии поясняют роль ControlPort,
  # SOCKSPort и шаблоны управления bridges. Это демонстрация практической
  # интеграции анонимных сетей на хосте.
  services.tor = {
    enable = true;
    client.enable = true;
    torsocks.enable = true;
    settings = {
      SOCKSPort = [ 9050 ];
      ControlPort = [ 9051 ];
      CookieAuthentication = true;
      # Default to no bridges so Tor can start. To enable bridges, set
      # services.tor.settings.Bridge in your Nix configuration or provide
      # Bridge lines in the template conf/tor-bridges.conf and re-run rebuild.
      UseBridges = 0;
      # Enable common pluggable transports. `lyrebird` is the obfs4 binary
      # shipped in nixpkgs (replacement for obfs4proxy). meek and snowflake
      # clients are provided by their packages below.
      ClientTransportPlugin = lib.mkForce [
        "obfs4 exec ${pkgs.obfs4}/bin/lyrebird"
        "meek exec ${pkgs.meek}/bin/meek-client"
        "snowflake exec ${pkgs.snowflake}/bin/snowflake-client"
      ];
      DNSPort = [ 9053 ];
      AutomapHostsOnResolve = true;
      AutomapHostsSuffixes = [ ".onion" ".exit" ];
    };
  };

  # I2P — дополнительный стек приватной сети (опция).
  services.i2p.enable = true;

  # Install example/template of bridges into /etc so operator can copy/edit it.
  # We don't manage the runtime /etc/tor/bridges.conf directly (that file must
  # be editable by the admin). Instead we place a template at
  # /etc/tor/bridges.conf.example and ensure at boot that a real
  # /etc/tor/bridges.conf exists by copying the template if missing.
  environment.etc."tor/bridges.conf.example".source = ../conf/tor-bridges.conf;

  systemd.services."tor-ensure-bridges" = {
    description = "Ensure /etc/tor/bridges.conf exists (create from template)";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = ''/bin/sh -c 'mkdir -p /etc/tor && if [ ! -e /etc/tor/bridges.conf ]; then cp /etc/tor/bridges.conf.example /etc/tor/bridges.conf && chown root:root /etc/tor/bridges.conf && chmod 0640 /etc/tor/bridges.conf; fi'"'';
    };
  };

  # Ensure awk is available during activation scripts (used by activate).
  environment.systemPackages = lib.mkForce (config.environment.systemPackages or []) ++ with pkgs; [ gawk ];

  # Открытые порты для служб приватности — доступны локально/для роутинга.
  networking.firewall = {
    allowedTCPPorts = [ 9050 9051 9052 9053 7657 4444 4445 ];
    allowedUDPPorts = [ 9564 ];
  };

  # Примечание: автоматическая перезагрузка при изменении bridges намеренно опущена.
  # Dynamic runtime reloading can be implemented later with a carefully
  # tested systemd.path/service that avoids triggering during activation.
}
