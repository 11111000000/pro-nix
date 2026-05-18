{ config, lib, pkgs, emacsPkg ? pkgs.emacs, ... }:

{
  # Public Home Manager entrypoint for pro-Emacs.
  # This file is intentionally thin: it only assembles the focused modules and
  # leaves the actual behavior to `core`, `exwm` and `agent`.
  imports = [
    ./core.nix
    ./exwm.nix
    ./agent.nix
  ];
}
