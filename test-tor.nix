{ pkgs, ... }:
{
  services.tor = {
    enable = true;
    client.enable = true;
    settings = {
      Include = "/etc/tor/bridges.conf";
    };
  };
  environment.etc."tor/bridges.conf".source = ./conf/tor-bridges.conf;
}
