# Файл: автосгенерированная шапка — комментарии рефакторятся
{ config, lib, pkgs, ... }:

let
  users = [ "az" "za" "la" "bo" ];
in
{
  home-manager = {
    extraSpecialArgs = { inherit pkgs; };
    backupFileExtension = "backup";
    useUserPackages = true;
  };

  home-manager.users = builtins.listToAttrs (map (name: {
    inherit name;
    value = {
      imports = [ ../emacs/home-manager.nix ];
      home.username = name;
      home.homeDirectory = "/home/${name}";
      home.stateVersion = "23.11";
        pro.emacs = {
          enable = true;
          gui.enable = true;
          # Packages that Nix will provide to Emacs at runtime. Keep this
          # list minimal and reproducible to avoid network installs on
          # user machines. Users may extend via `extraPackages` in their
          # host config; this list is authoritative for the portable profile.
          # Packages that Nix will provide to Emacs at runtime. We enumerate
          # the full set derived from nix/provided-packages.nix so Home Manager
          # installs the corresponding emacsPackages into the user's profile.
          providedPackages = [
            "ace-window" "avy" "cape" "consult" "consult-dash" "consult-eglot" "consult-projectile" "consult-yasnippet"
            "corfu" "corfu-posframe" "corfu-terminal" "dash-docs" "eglot" "elfeed" "expand-region" "gptel"
            "kind-icon" "magit" "marginalia" "nix-mode" "orderless" "org" "projectile" "rainbow-delimiters"
            "treemacs" "vertico" "vterm" "yasnippet"
          ];

          # Ensure the corresponding Nix emacsPackages are installed into the
          # user's profile so Emacs finds them on the load-path at runtime.
          extraPackages = [
            pkgs.emacsPackages.ace-window pkgs.emacsPackages.avy pkgs.emacsPackages.cape pkgs.emacsPackages.consult
            pkgs.emacsPackages.consult-dash pkgs.emacsPackages.consult-eglot pkgs.emacsPackages.consult-projectile pkgs.emacsPackages.consult-yasnippet
            pkgs.emacsPackages.corfu pkgs.emacsPackages.corfu-posframe pkgs.emacsPackages.corfu-terminal pkgs.emacsPackages.dash-docs
            pkgs.emacsPackages.eglot pkgs.emacsPackages.elfeed pkgs.emacsPackages.expand-region pkgs.emacsPackages.gptel
            pkgs.emacsPackages.kind-icon pkgs.emacsPackages.magit pkgs.emacsPackages.marginalia pkgs.emacsPackages.nix-mode
            pkgs.emacsPackages.orderless pkgs.emacsPackages.org pkgs.emacsPackages.projectile pkgs.emacsPackages.rainbow-delimiters
            pkgs.emacsPackages.treemacs pkgs.emacsPackages.vertico pkgs.emacsPackages.vterm pkgs.emacsPackages.yasnippet
          ];
        };
    };
  }) users);
}
