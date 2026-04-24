{ lib, pkgs, ... }:

{
  # Minimal runtime packages required for system operability and activation.
  environment.systemPackages = lib.mkDefault (with pkgs; [
    bashInteractive
    openssh
    dbus
    coreutils
    procps
    gawk
  ]);
}
