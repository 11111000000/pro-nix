{ lib, ... }:

{
  imports = [ ../../modules/pro-users.nix ];

  # CF-19: легаси, вращающиеся диски, старый AHCI
  boot.initrd.kernelModules = [ "ahci" ];

  networking.hostName = "cf19-pro";
  system.stateVersion = "25.05";

  boot.loader.systemd-boot.enable = lib.mkForce false;
  fileSystems."/" = lib.mkForce {
    device = "/dev/disk/by-uuid/zzz";
    fsType = "ext4";
  };
  fileSystems."/boot" = lib.mkForce {
    device = "/dev/disk/by-uuid/aaa";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };
  swapDevices = [ ];
}
