{ config, pkgs, ... }:
{
  imports = [
    ./modules/pro-privacy.nix
  ];

  networking.hostName = "test-host";
  boot.selector.label = "test";
}
