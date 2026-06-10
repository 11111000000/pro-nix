{ config, lib, pkgs, ... }:

let
  wifiRecover = pkgs.writeShellScriptBin "ops-wifi-recover" (builtins.readFile ../../scripts/ops-wifi-recover.sh);
in

{
  # CF-19: host-конфигурация описывает только железо и специфические
  # переопределения. Профиль окружения (минимальный EXWM и базовые пакеты)
  # задаётся через общие модули и hosts/cf19/composition.nix.
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

  # CF-19: Panasonic Let's Note CF-MX — BIOS-загрузка через GRUB без EFI-слоя.
  networking.hostName = "cf19";

  # Аппаратная поддержка
  hardware.cpu.intel.updateMicrocode = true;

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

  boot.initrd.kernelModules = [
    "ahci"
    "ata_piix"
    "usb_storage"
    "sd_mod"
  ];

  boot.resumeDevice = "/dev/disk/by-uuid/68ade83c-1e5b-4f37-a13f-2c386be87be6";

  boot.kernelParams = [
    "i8042.reset"
    "i8042.nomux"
    "mitigations=off"
    "preempt=full"
    "mem_sleep_default=s2idle"
  ];

  # CF-19 uses the shared TTY font policy from modules/tty-console.nix.
  # Host finalization does not override the default console font.

  # Ensure additional virtual consoles are available so switching from the
  # graphical session (Ctrl+Alt+F*) reliably reaches a text login. Enable
  # getty instances for tty2 and tty3 in addition to the default tty1.
  systemd.services."getty@tty2".enable = lib.mkDefault true;
  systemd.services."getty@tty3".enable = lib.mkDefault true;

  users.groups.netdev = lib.mkForce { };

  systemd.services.dbus = {
    reloadIfChanged = lib.mkForce false;
    restartIfChanged = lib.mkForce false;
    restartTriggers = lib.mkForce [ ];
    stopIfChanged = lib.mkForce false;
  };

  systemd.user.services.dbus = {
    reloadIfChanged = lib.mkForce false;
    restartIfChanged = lib.mkForce false;
    restartTriggers = lib.mkForce [ ];
    stopIfChanged = lib.mkForce false;
  };
  powerManagement.resumeCommands = lib.mkAfter ''
    for n in XHCI RP05; do
      if ${pkgs.gawk}/bin/gawk -v d="$n" '$1==d && $3 ~ /\*enabled/' /proc/acpi/wakeup >/dev/null 2>&1; then
        echo "$n" > /proc/acpi/wakeup || true
      fi
    done
    # WiFi reset: после s2idle чип может не переинициализироваться.
    ${wifiRecover}/bin/ops-wifi-recover || true
  '';

  powerManagement.powerUpCommands = lib.mkAfter ''
    for n in XHCI RP05; do
      if ${pkgs.gawk}/bin/gawk -v d="$n" '$1==d && $3 ~ /\*enabled/' /proc/acpi/wakeup >/dev/null 2>&1; then
        echo "$n" > /proc/acpi/wakeup || true
      fi
    done
    ${wifiRecover}/bin/ops-wifi-recover || true
  '';

  fileSystems."/" = lib.mkForce {
    device = "/dev/disk/by-uuid/d7d6e5f8-2c00-47ad-931a-a6b73a1cdcc2";
    fsType = "ext4";
  };

  # Host-specific hardware policy only; shared opencode/runtime policy lives at the top level.
  fileSystems."/boot" = lib.mkForce {
    device = "/dev/disk/by-uuid/c3ff38e8-0de3-427a-983f-86871ed38d32";
    fsType = "ext4";
  };

  # Ensure data partition /dev/sda4 is mounted on this host. UUID discovered during inspection: f422300d-3217-4bb8-b611-e88491c6901d
  # Используем /mnt/sda4 как точку монтирования; если хотите другое имя — скажите.
  fileSystems."/mnt/sda4" = lib.mkForce {
    device = "/dev/disk/by-uuid/f422300d-3217-4bb8-b611-e88491c6901d";
    fsType = "ext4";
    # уменьшает запись на диск для больших медиа-хранилищ
    options = [ "noatime" ];
  };

  swapDevices = [
    { device = "/dev/disk/by-uuid/68ade83c-1e5b-4f37-a13f-2c386be87be6"; }
  ];

  # Cinnamon не нужен на cf19: оставляем GDM + EXWM, но убираем тяжёлый
  # desktop branch. TTY-login сохраняется через tty1/tty2/tty3 и getty.
  services.xserver.desktopManager.cinnamon.enable = lib.mkForce false;
  # fbterm отключён: он занимает tty2 и может конфликтовать с запуском display manager.
  systemd.services."fbterm-tty2".enable = lib.mkForce false;

  # NFS-клиент: монтируем desktop:/srv/nfs автоматически по обращению.
  pro.nfs.client.enable = true;
}
