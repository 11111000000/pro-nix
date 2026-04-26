let
  pkgs = import <nixpkgs> {};
in
  (import ./emacs-recipes/agent-shell.nix)
