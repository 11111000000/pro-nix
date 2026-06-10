{ lib, pkgs, ... }:

{
  # Desktop uses exwm as minimal graphical environment and separately
  # gets compact app desktop layer without heavy desktop branch.
  pro.profiles.exwmMinimal.enable = lib.mkDefault true;

  environment.systemPackages = with pkgs; [
    # Essential Emacs overlay packages that are missing on desktop
    # These are provided by the emacs-extra overlay in the flake
  ];
}
