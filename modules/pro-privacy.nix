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
      SOCKSPort = [ 9052 ];
      ControlPort = [ 9051 ];
      CookieAuthentication = true;
      UseBridges = 1;
      ClientTransportPlugin = lib.mkForce [ "obfs4 exec ${pkgs.obfs4}/bin/lyrebird" ];
      Bridge = [
        # bridge: host:port fingerprint ... (оставляем явную настройку для оператора)
        "obfs4 157.131.86.3:4151 F09798E5258569811C71BFA98F43975E768CD8B8 cert=gRkZGmnzzzCwnSUT65285BkI1a8ni7R+7tXAYizYUzrlSklcX4rOtl7gU/9unBwblOQ3Ew iat-mode=0"
      ];
      DNSPort = [ 9053 ];
      AutomapHostsOnResolve = true;
      AutomapHostsSuffixes = [ ".onion" ".exit" ];
    };
  };

  # I2P: ещё один стек приватной сети, включается как опция.
  services.i2p.enable = true;

  # Открытые порты для служб приватности — доступны локально/для роутинга.
  networking.firewall = {
    allowedTCPPorts = [ 9050 9051 9053 7657 4444 4445 ];
    allowedUDPPorts = [ 9564 ];
  };
}
