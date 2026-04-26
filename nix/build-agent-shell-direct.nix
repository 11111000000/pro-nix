let
  pkgs = import <nixpkgs> {};
  inherit (pkgs) fetchFromGitHub stdenv;
in
  (import ./nix/emacs-recipes/agent-shell.nix) { inherit stdenv fetchFromGitHub; emacsPackages = pkgs.emacsPackages; }
