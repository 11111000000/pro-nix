{ lib, pkgs, ... }:
{
  # VM-профиль, максимально близкий к cf19, но с виртуальным диском и EFI-boot.
  imports = [
    ../../modules/pro-users.nix
  ];

  networking.hostName = "cf19-vm";

  # Базовая аппаратная политика cf19 (без жесткой привязки к конкретным UUID).
  hardware.cpu.intel.updateMicrocode = true;

  # В VM используем systemd-boot и виртуальный диск /dev/vda1.
  fileSystems."/" = {
    device = "/dev/vda1";
    fsType = "ext4";
  };

  boot.loader.grub.enable = lib.mkForce false;
  boot.loader.systemd-boot.enable = lib.mkForce true;
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

  # Минимальный набор сервисов, нужных для интерактивной работы и проверки dbus.
  services.xserver.enable = lib.mkForce false;
  services.displayManager.enable = lib.mkForce false;

  services.openssh.enable = true;

  # Sudo без пароля для удобства в тестовой VM.
  security.sudo.enable = true;
  security.sudo.wheelNeedsPassword = lib.mkForce false;

  users.users.root.password = "";

  # Наследуем общую политику пакетов (как в hosts/vm/configuration.nix).
}
