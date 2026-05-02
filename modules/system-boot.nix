# Название: modules/system-boot.nix — Загрузчик, ядро и базовые параметры загрузки
# Кратко: базовая конфигурация GRUB/EFI, выбор kernel package и системные sysctl.
#
# Цель:
#   Обеспечить воспроизводимые значения загрузчика и базовых kernel-опций, пригодные
#   для большинства десктоп/ноутбук-хостов. Хост может переопределять значения.
#
# Контракт:
#   Опции: boot.loader.*, boot.kernelPackages, boot.kernel.sysctl
#   Побочные эффекты: может включать plymouth spinner; устанавливает kernel.sysrq.
#
# Предпосылки:
#   Подходит для EFI-машин; на BIOS/legacy-хостах опции могут быть переопределены.
#
# Как проверить (Proof):
#   `nix build .#nixosConfigurations.<host>.config.system.build.toplevel`
#
# Last reviewed: 2026-05-02
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
