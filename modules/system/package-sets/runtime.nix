{ pkgs, ... }:

with pkgs;

{
  # Minimal runtime packages required by all hosts
  runtimePackages = [
    bashInteractive
    openssh
    python3
    coreutils
    procps
    dbus
    gawk
  ];
}
