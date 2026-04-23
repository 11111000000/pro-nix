# Файл: автосгенерированная шапка — комментарии рефакторятся
{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "thunderbolt" "vmd" "ahci" "nvme" "uas" "usb_storage" "sd_mod" "sdhci_pci" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.kernelParams = [ "mem_sleep_default=deep" ];
  boot.extraModulePackages = [ ];

  # Host-specific storage belongs in the host profile, not in this shared scan file.
  # Keep this file limited to hardware that is shared across targets.

  # Контекст:
  # DHCP — базовый механизм получения сетевых настроек. В крупных конфигурациях
  # рекомендуется явно задавать поведение для каждого интерфейса при помощи
  # `networking.interfaces.<interface>.useDHCP`, чтобы избежать неявных конфликтов
  # между сетевыми менеджерами (NetworkManager, systemd-networkd и т.п.).
  # networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp43s0.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlp0s20f3.useDHCP = lib.mkDefault true;

  # nixpkgs.hostPlatform можно опустить — по умолчанию x86_64-linux. Указывайте только если нужна другая архитектура.
  # nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
