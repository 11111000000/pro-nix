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
      Include = "/etc/tor/bridges.conf";
      DNSPort = [ 9053 ];
      AutomapHostsOnResolve = true;
      AutomapHostsSuffixes = [ ".onion" ".exit" ];
    };
  };

  # I2P: ещё один стек приватной сети, включается как опция.
  services.i2p.enable = true;

  # Мосты Tor хранятся в отдельном файле для runtime-управления без rebuild
  environment.etc."tor/bridges.conf".source = ../conf/tor-bridges.conf;

  # Открытые порты для служб приватности — доступны локально/для роутинга.
  networking.firewall = {
    allowedTCPPorts = [ 9050 9051 9052 9053 7657 4444 4445 ];
    allowedUDPPorts = [ 9564 ];
  };

  # Автоматически перезагружать Tor при изменении bridges.conf
  systemd.services."tor-bridges-reload" = lib.mkIf true {
    description = "Reload Tor when bridges configuration changes";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.systemd}/bin/systemctl reload tor.service";
    };
  };

  systemd.paths."tor-bridges-reload" = lib.mkIf true {
    description = "Watch for changes to /etc/tor/bridges.conf";
    wantedBy = [ "multi-user.target" ];
    pathConfig = {
      PathExists = "/etc/tor/bridges.conf";
      Unit = "tor-bridges-reload.service";
    };
  };
}
