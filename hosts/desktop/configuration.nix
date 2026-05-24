{ lib, pkgs, ... }:

{
  imports = [
    ../../modules/pro-users.nix
    ../../modules/pro-haskell.nix
    ../../modules/pro-heavy-desktop.nix
  ];

  networking.hostName = "desktop";

  # Аппаратная поддержка
  hardware.cpu.intel.updateMicrocode = true;

  boot.loader.systemd-boot.enable = lib.mkForce true;
  boot.loader.grub.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = lib.mkForce true;
  boot.loader.efi.efiSysMountPoint = "/boot";
  boot.loader.systemd-boot.configurationLimit = 6;
  boot.loader.timeout = 5;

  boot.kernelPackages = lib.mkForce pkgs.linuxPackages_latest;
  boot.kernelParams = [
    "nvme_core.default_ps_max_latency_us=5500"
  ];
  boot.extraModprobeConfig = "options btusb enable_autosuspend=0";

  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = lib.mkForce {
    device = "/dev/disk/by-uuid/ef0ab8ba-27f8-4595-8595-79390078ef46";
    fsType = "ext4";
    options = [ "noatime" ];
  };

  fileSystems."/boot" = lib.mkForce {
    device = "/dev/disk/by-uuid/B994-87FC";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };

  fileSystems."/mnt/storage" = lib.mkForce {
    device = "/dev/disk/by-uuid/23ab71c8-d86f-4f92-802a-9cb706261f3f";
    fsType = "ext4";
    options = [ "noatime" ];
  };

  swapDevices = [ ];

  services.zramSlice = {
    enable = true;
    size = "auto";
  };

  services.resolved = {
    enable = true;
    llmnr = "false";
    extraConfig = builtins.readFile ../../conf/resolved-extra.conf;
  };
}
