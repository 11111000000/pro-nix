# Русский: комментарии и пояснения оформлены в стиле учебника
{ config, lib, pkgs, ... }:

{
  # Import modules for this host
  imports = [
    ../../modules/pro-users.nix
    # adb-udev intentionally not imported here to avoid permission issues during build
    # ../../nixos/modules/adb-udev.nix
  ];

  networking.hostName = "huawei";
  system.stateVersion = "25.11";

  hardware.enableAllFirmware = true;
  hardware.cpu.intel.updateMicrocode = true;
  hardware.uinput.enable = true;
  hardware.firmware = [ pkgs.sof-firmware ];

  boot.kernelParams = [
    "mem_sleep_default=s2idle"
    "i915.enable_psr=0"
    "nvme_core.default_ps_max_latency_us=0"
    "acpi_backlight=native"
  ];
  boot.resumeDevice = "/dev/nvme0n1p3";
  boot.extraModprobeConfig = ''
    options snd-intel-dspcfg dsp_driver=1
  '';

  # Use systemd-boot here: firmware already uses systemd-boot as default. Keep host-specific differences here.
  boot.loader.systemd-boot.enable = lib.mkForce true;
  # Disable GRUB to avoid conflicting bootloader state
  boot.loader.grub.enable = lib.mkForce false;
  # Ensure we don't write to EFI NVRAM from this host (consistent with cf19 policy)
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;
 
  fileSystems."/" = lib.mkForce {
    device = "/dev/disk/by-uuid/b7a0681a-d1e2-4898-b213-f060d77b292a";
    fsType = "ext4";
  };

  # Pro-peer configuration: enable LAN discovery, key sync only (no Tor by default on laptop)
  pro-peer.enable = true;
  pro-peer.enableKeySync = true;
  pro-peer.keysGpgPath = "/etc/pro-peer/authorized_keys.gpg";
  pro-peer.keySyncInterval = "1h";
  pro-peer.allowTorHiddenService = false;

  # SSH hardening
  services.openssh.extraConfig = ''
PermitEmptyPasswords no
MaxAuthTries 3
X11Forwarding no
AllowTcpForwarding no
'';

  # Firewall: restrict SSH to LAN only (declarative)
  networking.firewall.enable = true;
  # Preserve and extend global defaults rather than overwrite them so Tor
  # ports (9050/9051/9053) added globally remain available on all hosts.
  networking.firewall.extraCommands = lib.mkAfter ''
    # allow SSH from RFC1918 ranges and loopback
    iptables -I INPUT -p tcp -s 10.0.0.0/8 --dport 22 -j ACCEPT || true
    iptables -I INPUT -p tcp -s 172.16.0.0/12 --dport 22 -j ACCEPT || true
    iptables -I INPUT -p tcp -s 192.168.0.0/16 --dport 22 -j ACCEPT || true
    iptables -I INPUT -p tcp -s 127.0.0.0/8 --dport 22 -j ACCEPT || true
    iptables -I INPUT -p tcp --dport 22 -j DROP || true
  '';
  fileSystems."/boot" = lib.mkForce {
    device = "/dev/disk/by-uuid/6DD0-A9CB";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };
  swapDevices = [
    { device = "/dev/disk/by-uuid/422bf68d-025a-4c1b-a3ba-c282ab7d4884"; }
  ];

  # Enable opencode default config installation for users
  opencode.enable = true;

  # Enable automatic zram setup and opencode slice with conservative defaults
  services.zramSlice = {
    enable = true;
    size = "auto"; # auto = 50% RAM, capped
  };

  services.opencodeSlice = {
    enable = true;
    memoryMax = "4G"; # limit heavy agents to ~4G by default on this laptop
    cpuQuota = "80%";
    ioWeight = 200;
  };

  # Host-specific guarantee: ensure essential interactive utilities are present
  # Use lib.mkForce at host level to ensure operator-required tools (mc) are
  # available even if module aggregation changed elsewhere.
  # Add mc as a low-priority contribution so it merges with other module-provided lists
  environment.systemPackages = lib.mkDefault ((config.environment.systemPackages or []) ++ [ pkgs.mc ]);
}
