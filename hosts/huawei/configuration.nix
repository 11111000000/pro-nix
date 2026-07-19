{ lib, pkgs, ... }:

{
  # Import modules for this host
  imports = [
    ../../modules/pro-haskell.nix
  ];

  networking.hostName = "huawei";

  nix.settings.max-jobs = lib.mkForce 1;
  nix.settings.cores = lib.mkForce 2;


  hardware.cpu.intel.updateMicrocode = true;
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

  fileSystems."/boot" = lib.mkForce {
    device = "/dev/disk/by-uuid/6DD0-A9CB";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };
  swapDevices = [
    { device = "/dev/disk/by-uuid/422bf68d-025a-4c1b-a3ba-c282ab7d4884"; }
  ];

  # opencode removed; zram slice remains enabled
  services.zramSlice = {
    enable = true;
    size = "auto"; # auto = 50% RAM, capped
  };

  # All hosts should expose the same browser/runtime stack unless hardware
  # forces an exception. Tor Browser lives in the shared package composition.

  # NFS-клиент: монтируем station:/srv/nfs автоматически по обращению.
  # При недоступном сервере (другая подсеть, нет mDNS/headscale) — mount
  # уходит в failed через ~3 с (nofail,soft,timeo=10,retrans=1), ничего
  # не блокирует. Диагностика: `journalctl -u mnt-station.mount`.
  pro.nfs.client.enable = true;

  # headscale control plane — на station; на ноутбуке выключаем явно.
  headscale.enable = lib.mkForce false;

  # Spell checker (ru_RU + optional en_US). Включаем на рабочей станции,
  # так как Emacs flyspell нужен для комментариев в коде и org-режиме.
  pro.spellcheck.enable = true;
}
