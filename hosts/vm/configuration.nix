{ config, lib, pkgs, ... }:

{
  networking.hostName = "vm";
  system.stateVersion = "25.11";

fileSystems."/" = {
    device = "/dev/sda1";
    fsType = "ext4";
  };

  boot.loader.grub.enable = lib.mkForce false;
  boot.loader.systemd-boot.enable = lib.mkForce true;
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

  services.xserver.enable = lib.mkForce false;
  services.displayManager.enable = lib.mkForce false;

  services.openssh.enable = true;

  security.sudo.enable = true;
  security.sudo.wheelNeedsPassword = lib.mkForce false;

  users.users.root.password = "";
}