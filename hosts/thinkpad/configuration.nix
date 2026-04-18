{ lib, ... }:

{
  imports = [ ../../modules/pro-users.nix ];

  # Аппаратные модули ThinkPad
  boot.initrd.kernelModules = [ "xhci_pci" "thunderbolt" "vmd" ];
  hardware.cpu.intel.updateMicrocode = lib.mkDefault true;

  networking.hostName = "thinkpad-pro";
  system.stateVersion = "25.05";

  boot.loader.systemd-boot.enable = lib.mkForce false;
  fileSystems."/" = lib.mkForce {
    device = "/dev/disk/by-uuid/b7a0681a-d1e2-4898-b213-f060d77b292a";
    fsType = "ext4";
  };
  fileSystems."/boot" = lib.mkForce {
    device = "/dev/disk/by-uuid/6DD0-A9CB";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };
  swapDevices = [
    { device = "/dev/disk/by-uuid/422bf68d-025a-4c1b-a3ba-c282ab7d4884"; }
  ];
}
