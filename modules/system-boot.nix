{ config, pkgs, lib, ... }:

{
  # Boot loader and kernel baseline suitable for most hosts.
  boot.loader.grub.enable = true;
  boot.loader.grub.device = lib.mkDefault "nodev";
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;
  boot.loader.efi.efiSysMountPoint = lib.mkDefault "/boot";
  boot.loader.timeout = 5;
  boot.loader.grub.useOSProber = false;

  boot.plymouth.enable = true;
  boot.plymouth.theme = "spinner";

  # LTS kernel; adjust per-host if needed.
  boot.kernelPackages = pkgs.linuxPackages_6_6;
  boot.kernel.sysctl."kernel.sysrq" = 1;
}
