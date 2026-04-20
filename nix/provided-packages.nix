{ pkgs, ... }:

let
  emacsPackages = [ pkgs.emacsPackages.magit pkgs.emacsPackages.consult pkgs.emacsPackages.vertico pkgs.emacsPackages.orderless pkgs.emacsPackages.marginalia pkgs.emacsPackages.gptel ];
  names = builtins.concatStringsSep " " (map (p: builtins.substring 0 100 (toString p)) emacsPackages);
in
{
  # This file is a helper placeholder. In your flake/home-manager module
  # you should create ~/.config/emacs/provided-packages.el with content like:
  # (setq pro-packages-provided-by-nix '(consult magit vertico ...))
}
