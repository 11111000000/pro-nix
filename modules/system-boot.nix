# Название: modules/system-boot.nix — Загрузчик и параметры ядра
# Summary (EN): GRUB, EFI, kernel and boot-time sysctl settings
# Цель:
#   Задать базовые параметры загрузки: GRUB, EFI, LTS-ядро и sysctl для
#   устойчивой работы хоста.
# Контракт:
#   Опции: boot.loader.*, boot.kernelPackages, boot.kernel.sysctl
#   Побочные эффекты: устанавливает plymouth spinner; включает sysrq.
# Предпосылки:
#   Требуется EFI-совместимая машина; GRUB должен поддерживаться.
# Как проверить (Proof):
#   `nix build .#nixosConfigurations.<host>.config.system.build.toplevel`
# Last reviewed: 2026-04-25
{ config, pkgs, lib, ... }:

{
  # Boot loader and kernel baseline suitable for most hosts.
  boot.loader.grub.enable = true;
  boot.loader.grub.device = lib.mkDefault "nodev";
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;
  boot.loader.efi.efiSysMountPoint = lib.mkDefault "/boot";
  boot.loader.timeout = 5;
  boot.loader.grub.useOSProber = false;

  boot.plymouth.enable = true;
  boot.plymouth.theme = "spinner";

  # LTS kernel; adjust per-host if needed.
  boot.kernelPackages = pkgs.linuxPackages_6_6;
  boot.kernel.sysctl."kernel.sysrq" = 1;
}
