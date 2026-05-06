/* RU: Файловый контракт — Home Manager для стандартных пользователей
   Цель: подключать общий Emacs-профиль к учётным записям, созданным в `pro-users.nix`.
   Контракт: для каждого стандартного пользователя импортируется `emacs/home-manager.nix`.
   Побочные эффекты: на всех пользовательских профилях появляется единый набор HM-настроек.
   Proof: `nix eval .#nixosConfigurations.<host>.config.home-manager.users`.
   Last reviewed: 2026-05-06
*/
{ config, lib, pkgs, ... }:

{
  home-manager.users = builtins.listToAttrs (map (name: {
    inherit name;
    value = {
      imports = [ ../emacs/home-manager.nix ];
      home.username = name;
      home.homeDirectory = "/home/${name}";
      home.stateVersion = "23.11";
      pro.emacs = {
        enable = true;
        gui.enable = false;
        providedPackages = [
          "ace-window" "avy" "cape" "consult" "consult-dash" "consult-eglot" "consult-projectile" "consult-yasnippet"
          "corfu" "corfu-posframe" "corfu-terminal" "dash-docs" "eglot" "elfeed" "expand-region" "gptel"
          "kind-icon" "magit" "marginalia" "nix-mode" "orderless" "org" "projectile" "rainbow-delimiters"
          "treemacs" "vertico" "vterm" "yasnippet" "embark-consult" "dash-docs" "consult-dash"
        ];

        extraPackages = [
          pkgs.emacsPackages.ace-window pkgs.emacsPackages.avy pkgs.emacsPackages.cape pkgs.emacsPackages.consult
          pkgs.emacsPackages.consult-dash pkgs.emacsPackages.consult-eglot pkgs.emacsPackages.consult-projectile pkgs.emacsPackages.consult-yasnippet
          pkgs.emacsPackages.corfu pkgs.emacsPackages.dash-docs pkgs.emacsPackages.consult-dash pkgs.emacsPackages.embark-consult
          pkgs.emacsPackages.eglot pkgs.emacsPackages.elfeed pkgs.emacsPackages.expand-region pkgs.emacsPackages.gptel
          pkgs.emacsPackages.kind-icon pkgs.emacsPackages.magit pkgs.emacsPackages.marginalia pkgs.emacsPackages.nix-mode
          pkgs.emacsPackages.orderless pkgs.emacsPackages.org pkgs.emacsPackages.projectile pkgs.emacsPackages.rainbow-delimiters
          pkgs.emacsPackages.treemacs pkgs.emacsPackages.vertico pkgs.emacsPackages.vterm pkgs.emacsPackages.yasnippet
        ];
      };
    };
  }) [ "az" "za" "la" "bo" ]);
}
