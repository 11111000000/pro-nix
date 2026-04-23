{ pkgs ? import <nixpkgs> {} }:

let
  emacsPkgs = with pkgs.emacsPackages; [ vertico consult orderless corfu cape vterm ace-window embark marginalia consult-dash consult-eglot consult-yasnippet ];
in
pkgs.emacsWithPackages (epkgs: with epkgs; emacsPkgs)
