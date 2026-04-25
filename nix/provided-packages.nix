{ pkgs, ... }:

let
  emacsPackages = [
    pkgs.emacsPackages.magit
    pkgs.emacsPackages.consult
    pkgs.emacsPackages.vertico
    pkgs.emacsPackages.orderless
    pkgs.emacsPackages.marginalia
    pkgs.emacsPackages.gptel
    pkgs.emacsPackages.consult-dash
    pkgs.emacsPackages.dash-docs
    pkgs.emacsPackages.consult-eglot
    pkgs.emacsPackages.consult-yasnippet
    pkgs.emacsPackages.corfu
    pkgs.emacsPackages.cape
    pkgs.emacsPackages.kind-icon
    pkgs.emacsPackages.avy
    pkgs.emacsPackages.expand-region
    pkgs.emacsPackages.yasnippet
    pkgs.emacsPackages.projectile
    pkgs.emacsPackages.treemacs
    pkgs.emacsPackages.consult-projectile
    pkgs.emacsPackages.elfeed
    pkgs.emacsPackages.eglot
    pkgs.emacsPackages.rainbow-delimiters
    pkgs.emacsPackages.nix-mode
    pkgs.emacsPackages.mmm-mode
    pkgs.emacsPackages.org
    pkgs.emacsPackages.vterm
    pkgs.emacsPackages.ace-window
  ];
  names = builtins.concatStringsSep " " (map (p: builtins.substring 0 100 (toString p)) emacsPackages);
in
{
  # This file is a helper placeholder. To materialize an Emacs Lisp list of
  # packages provided by Nix, you can run the helper script:
  #
  # emacs --batch -l scripts/regenerate-provided-packages.el \
  #       --eval '(generate-provided-packages "nix/provided-packages.nix" "~/.config/emacs/provided-packages.el")'
  #
  # The script will write `~/.config/emacs/provided-packages.el` which sets
  # `pro-packages-provided-by-nix` for `site-init.el` to pick up at startup.
}
