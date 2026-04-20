{ lib, pkgs, ... }:

{
  imports = [ ../../modules/pro-users.nix ];

  # CF-19: Panasonic Let's Note CF-MX — BIOS-загрузка через GRUB без EFI-слоя.
  networking.hostName = "cf19";
  system.stateVersion = "25.05";

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
  fileSystems."/boot" = lib.mkForce {
    device = "/dev/disk/by-uuid/c3ff38e8-0de3-427a-983f-86871ed38d32";
    fsType = "ext4";
  };
  swapDevices = [
    { device = "/dev/disk/by-uuid/68ade83c-1e5b-4f37-a13f-2c386be87be6"; }
  ];
}
