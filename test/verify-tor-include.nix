{ pkgs, ... }:
{
  # Minimal check: services.tor should include the bridges file by default so
  # hosts can drop /etc/tor/bridges.conf without using deprecated extraConfig.
  services.tor.settings = {
    Include = "/etc/tor/bridges.conf";
  };
}
