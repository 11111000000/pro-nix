{ config, pkgs, lib, emacsPkg, ... }:

{
  services.xserver.enable = lib.mkDefault true;

  # EXWM session xsession entry for display managers and user session files
  environment.etc."X11/sessions/exwm.desktop" = lib.mkIf false { text = ""; };

  # Do not enable heavy desktop components here. This module provides
  # session glue only; packages are provided via modules/system/package-sets/exwm.nix
}
