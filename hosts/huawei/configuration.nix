# Русский: комментарии и пояснения оформлены в стиле учебника
{ lib, pkgs, ... }:

{
  imports = [ ../../modules/pro-users.nix ];

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

  boot.loader.systemd-boot.enable = lib.mkForce false;
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
  networking.firewall.allowedTCPPorts = [ 22 ];
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
}
