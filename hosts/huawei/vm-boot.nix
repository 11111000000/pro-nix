{ lib, ... }:

{
  networking.hostName = "huawei-vm";

  virtualisation.memorySize = 2048;
  virtualisation.cores = 2;
  virtualisation.diskSize = 8192;

  boot.loader.grub.enable = lib.mkForce false;
  boot.loader.systemd-boot.enable = lib.mkForce true;
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

  services.xserver.enable = lib.mkForce false;
  services.displayManager.gdm.enable = lib.mkForce false;
  services.xserver.desktopManager.cinnamon.enable = lib.mkForce false;
  services.openssh.enable = lib.mkForce false;

  fileSystems."/" = lib.mkForce {
    device = "/dev/vda1";
    fsType = "ext4";
  };

  fileSystems."/boot" = lib.mkForce {
    device = "/dev/vda2";
    fsType = "vfat";
  };

  swapDevices = lib.mkForce [ ];
  boot.resumeDevice = lib.mkForce "";
}
