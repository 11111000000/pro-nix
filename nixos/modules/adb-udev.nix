{ config, pkgs, lib, ... }:

# NixOS module: install udev rules for Android devices (adb) so devices are
# accessible without sudo after a nixos-rebuild switch. This copy is intended
# to be imported into the pro-nix global host modules so rules apply for all hosts.

{
  options = { };

  config = {
    environment.etc."udev/rules.d/51-android.rules".text = lib.concatStringsSep "\n" [
      "# Android / common vendors - allow user access to adb without sudo"
      "# Huawei"
      "SUBSYSTEM==\"usb\", ATTR{idVendor}==\"12d1\", MODE=\"0666\""
      "# Google"
      "SUBSYSTEM==\"usb\", ATTR{idVendor}==\"18d1\", MODE=\"0666\""
      "# Samsung"
      "SUBSYSTEM==\"usb\", ATTR{idVendor}==\"04e8\", MODE=\"0666\""
      "# HTC"
      "SUBSYSTEM==\"usb\", ATTR{idVendor}==\"0bb4\", MODE=\"0666\""
    ];

    # Optional: install android platform-tools system-wide via Nix. Left
    # commented because platform-tools may be unfree in some nixpkgs
    # channel/configurations and users may prefer installing via distro or
    # using the local ./tools download already provided in this repo.
    # environment.systemPackages = with pkgs; [ androidsdkplatformtools ];
  };
}
