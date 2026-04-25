# Название: modules/pro-users-nixos.nix — Home Manager для NixOS
# Summary (EN): Home Manager configuration for NixOS users
# Цель:
#   Определить NixOS-специфичную часть Home Manager: настройки Emacs,
#   пользовательские профили и пакеты из provided.
# Контракт:
#   Опции: home-manager.users, home-manager.users.*.pro.emacs.*
#   Побочные эффекты: настраивает Emacs-профиль через Home Manager для каждого пользователя.
# Предпосылки:
#   Требуется Home Manager и NixOS; список пакетов берётся из provided/.
# Как проверить (Proof):
#   `systemctl status home-manager-az` (если активирован)
# Last reviewed: 2026-04-25
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
            pkgs.emacsPackages.corfu pkgs.emacsPackages.dash-docs
            pkgs.emacsPackages.eglot pkgs.emacsPackages.elfeed pkgs.emacsPackages.expand-region pkgs.emacsPackages.gptel
            pkgs.emacsPackages.kind-icon pkgs.emacsPackages.magit pkgs.emacsPackages.marginalia pkgs.emacsPackages.nix-mode
            pkgs.emacsPackages.orderless pkgs.emacsPackages.org pkgs.emacsPackages.projectile pkgs.emacsPackages.rainbow-delimiters
            pkgs.emacsPackages.treemacs pkgs.emacsPackages.vertico pkgs.emacsPackages.vterm pkgs.emacsPackages.yasnippet
          ];
        };
    };
  }) users);
}
