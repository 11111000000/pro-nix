let
  pkgs = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/refs/tags/nixos-25.11.tar.gz";
  }) {};
in
  (import ./emacs-recipes/agent-shell.nix)
