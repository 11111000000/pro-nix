{ lib, ... }:

{
  imports = [ ../../modules/pro-users.nix ];

  # Desktop: мощный GPU, NVMe, нет Thunderbolt
  boot.initrd.kernelModules = [ "xhci_pci" "ahci" "nvme" ];
  hardware.cpu.intel.updateMicrocode = lib.mkDefault true;
  hardware.uinput.enable = lib.mkDefault true;

  networking.hostName = "desktop-pro";
  system.stateVersion = "25.05";

  boot.loader.systemd-boot.enable = lib.mkForce false;
  fileSystems."/" = lib.mkForce {
    device = "/dev/disk/by-uuid/xxx";
    fsType = "ext4";
  };
  fileSystems."/boot" = lib.mkForce {
    device = "/dev/disk/by-uuid/yyy";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };
  swapDevices = [ ];
}
