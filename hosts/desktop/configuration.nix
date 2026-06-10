{ lib, pkgs, ... }:

{
  imports = [
    ../../modules/pro-users.nix
    ../../modules/pro-desktop.nix
    ../../modules/pro-heavy-desktop.nix
    ../../modules/profile-exwm-minimal.nix
    ../../modules/session-exwm.nix
    ../../modules/session-sway.nix
    ../../modules/session-i3.nix
    ./composition.nix
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

  # audit не работает на desktop — /etc/passwd, /etc/shadow, /etc/group
  # ведут symlink-ами в /.host-etc/ через границу монтирования, и auditctl
  # не может наложить watch-правила. Отключаем audit для этого хоста.
  security.audit.enable = false;

  services.zramSlice = {
    enable = true;
    size = "auto";
  };

  services.resolved = {
    enable = true;
    # LLMNR off — нам хватает mDNS (Avahi) для .local, LLMNR создаёт
    # конфликты с split-horizon DNS и не нужен в нашей сети.
    llmnr = "false";
    extraConfig = builtins.readFile ../../conf/resolved-extra.conf;
  };

# Desktop — fileserver для LAN. NFS-export /srv/nfs (члены pro группы
# могут писать, setgid). Syncthing в pro-storage.nix уже шарит
# /srv/syncthing автоматически.
  pro.nfs.server.enable = true;
  pro.nfs.server.exportPath = "/srv/nfs";
  pro.nfs.client.enable = true;
}
