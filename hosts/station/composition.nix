{ lib, pkgs, ... }:

let
  runtime = import ../../modules/system-package-sets-runtime.nix { inherit pkgs; };
  tor = import ../../modules/system-package-sets-tor.nix { inherit pkgs; };
in
{
  # Station uses exwm as minimal graphical environment and separately
  # gets compact app desktop layer without heavy desktop branch.
  pro.profiles.exwmMinimal.enable = lib.mkDefault true;

  environment.systemPackages = runtime.runtimePackages
    ++ tor.torControlPackages
    ++ (with pkgs; [
    # Essential Emacs overlay packages that are missing on station
    # These are provided by the emacs-extra overlay in the flake
  ]);
}
