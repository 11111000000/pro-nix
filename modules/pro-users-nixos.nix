# Файл: автосгенерированная шапка — комментарии рефакторятся
{ config, lib, pkgs, ... }:

let
  users = [ "az" "zo" "la" "bo" ];
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
          providedPackages = [ "consult" "magit" "vertico" "orderless" "marginalia" "corfu" "gptel" ];
          # Ensure the corresponding Nix packages are actually installed into
          # the user's profile so Emacs finds them on the load-path at runtime.
          extraPackages = [ pkgs.emacsPackages.consult pkgs.emacsPackages.magit pkgs.emacsPackages.vertico pkgs.emacsPackages.orderless pkgs.emacsPackages.marginalia pkgs.emacsPackages.corfu pkgs.emacsPackages.gptel ];
        };
    };
  }) users);
}
