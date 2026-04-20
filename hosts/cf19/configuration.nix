{ lib, pkgs, ... }:

{
  imports = [ ../../modules/pro-users.nix ];

  # CF-19: Panasonic Let's Note CF-MX — BIOS-загрузка через GRUB без EFI-слоя.
  networking.hostName = "cf19";
  system.stateVersion = "25.11";

  # Аппаратная поддержка
  hardware.enableAllFirmware = true;
  hardware.cpu.intel.updateMicrocode = true;
  hardware.uinput.enable = true;

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

  boot.initrd.kernelModules = [
    "ahci"
    "ata_piix"
    "usb_storage"
    "sd_mod"
  ];

  boot.kernelParams = [
    "i8042.reset"
    "i8042.nomux"
    "mitigations=off"
    "preempt=full"
    "nohibernate"
    "mem_sleep_default=s2idle"
  ];

  console.font = lib.mkForce "${pkgs.kbd}/share/consolefonts/latarcyrheb-sun16.psfu.gz";

  powerManagement.resumeCommands = lib.mkAfter ''
    for n in XHCI RP05; do
      if awk -v d="$n" '$1==d && $3 ~ /\*enabled/' /proc/acpi/wakeup >/dev/null 2>&1; then
        echo "$n" > /proc/acpi/wakeup || true
      fi
    done
  '';

  powerManagement.powerUpCommands = lib.mkAfter ''
    for n in XHCI RP05; do
      if awk -v d="$n" '$1==d && $3 ~ /\*enabled/' /proc/acpi/wakeup >/dev/null 2>&1; then
        echo "$n" > /proc/acpi/wakeup || true
      fi
    done
  '';

  fileSystems."/" = lib.mkForce {
    device = "/dev/disk/by-uuid/d7d6e5f8-2c00-47ad-931a-a6b73a1cdcc2";
    fsType = "ext4";
  };

  # Pro-peer configuration: enable LAN discovery, key sync and Tor hidden service for SSH
  pro-peer.enable = true;
  pro-peer.enableKeySync = true;
  pro-peer.keysGpgPath = "/etc/pro-peer/authorized_keys.gpg";
  pro-peer.keySyncInterval = "1h";
  pro-peer.allowTorHiddenService = true;
  # do not set torBackupRecipient in repo (secrets must be provided out-of-band)
  pro-peer.torBackupRecipient = null;

  # Ensure Nix experimental features required for this configuration are enabled
  # This writes into the generated /etc/nix/nix.conf via the nix.extraOptions option
  # Ensure Nix experimental features required for this configuration are enabled.
  # Keep this minimal and explicit; the generated /etc/nix/nix.conf will include
  # these extra options after a successful rebuild.
  nix = {
    extraOptions = ''
experimental-features = nix-command flakes cgroups
    '';
  };

  # SSH hardening: restrict interactive features for remote connections
  services.openssh = {
    extraConfig = ''
# Pro-peer hardening
PermitEmptyPasswords no
MaxAuthTries 3
X11Forwarding no
# Prevent port forwarding from untrusted sources by default; individual keys may allow via forced-command
AllowTcpForwarding no
'';
  };

  # Firewall: allow SSH only from private networks and loopback; all other SSH connections dropped
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
    device = "/dev/disk/by-uuid/c3ff38e8-0de3-427a-983f-86871ed38d32";
    fsType = "ext4";
  };
  swapDevices = [
    { device = "/dev/disk/by-uuid/68ade83c-1e5b-4f37-a13f-2c386be87be6"; }
  ];
}
