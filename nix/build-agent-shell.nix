let
  pkgs = import <nixpkgs> {};
  pkgsOverlay = import <nixpkgs> { overlays = [ (import ./overlays/emacs-extra.nix) ]; };
in pkgsOverlay.emacsPackages.agent-shell
