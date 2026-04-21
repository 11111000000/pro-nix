# Файл: автосгенерированная шапка — комментарии рефакторятся
{ pkgs, lib, ... }:

{
  # Службы приватности и анонимного доступа.
  # Tor: клиентская конфигурация с локальным SOCKS прокси и ControlPort.
  # Используем bridges и obfs4 транспорты для обхода сетевых ограничений.
  services.tor = {
    enable = true;
    client.enable = true;
    torsocks.enable = true;
    settings = {
      SOCKSPort = [ 9050 ];
      ControlPort = [ 9051 ];
      CookieAuthentication = true;
      UseBridges = 1;
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

  # I2P: ещё один стек приватной сети, включается как опция.
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

  # Открытые порты для служб приватности — доступны локально/для роутинга.
  networking.firewall = {
    allowedTCPPorts = [ 9050 9051 9052 9053 7657 4444 4445 ];
    allowedUDPPorts = [ 9564 ];
  };

  # NOTE: automatic reload on bridges changes is intentionally omitted here.
  # Dynamic runtime reloading can be implemented later with a carefully
  # tested systemd.path/service that avoids triggering during activation.
}
