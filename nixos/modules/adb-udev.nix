{ config, pkgs, lib, ... }:

# NixOS module: install udev rules for Android devices (adb) so devices are
# accessible without sudo after a nixos-rebuild switch. This copy is intended
# to be imported into the pro-nix global host modules so rules apply for all hosts.

{
  options = { };

  config = {
    # Use group=plugdev and MODE=0660 to restrict access to users in plugdev.
    # We also add a simple udev rule that sets proper permissions for common
    # Android vendors; this is preferred over MODE=0666 for security.
    environment.etc."udev/rules.d/51-android.rules".text = lib.concatStringsSep "\n" [
      "# Android / common vendors - allow user access to adb by group 'plugdev'"
      "# Huawei"
      "SUBSYSTEM==\"usb\", ATTR{idVendor}==\"12d1\", GROUP=\"plugdev\", MODE=\"0660\""
      "# Google"
      "SUBSYSTEM==\"usb\", ATTR{idVendor}==\"18d1\", GROUP=\"plugdev\", MODE=\"0660\""
      "# Samsung"
      "SUBSYSTEM==\"usb\", ATTR{idVendor}==\"04e8\", GROUP=\"plugdev\", MODE=\"0660\""
      "# HTC"
      "SUBSYSTEM==\"usb\", ATTR{idVendor}==\"0bb4\", GROUP=\"plugdev\", MODE=\"0660\""
    ];

    # Ensure plugdev group exists and add all local users to it so adb access
    # becomes available to all interactive users on the system.
    users.extraGroups.plugdev = {
      gid = 3000; # arbitrary high GID to avoid conflicts
      members = lib.mapAttrsToList (name: value: name) (config.users.users or {});
    };

    # Optional: install android platform-tools system-wide via Nix. Left
    # commented because platform-tools may be unfree in some nixpkgs
    # channel/configurations and users may prefer installing via distro or
    # using the local ./tools download already provided in this repo.
    # environment.systemPackages = with pkgs; [ androidsdkplatformtools ];
  };
}
