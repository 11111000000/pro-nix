{ config, lib, pkgs, opencodeBwrapModule ? null, ... }:

{
  home-manager.users = builtins.listToAttrs (map (name: {
    inherit name;
    value = {
      imports = [ ../emacs/home-manager.nix ./opencode-tui.nix ./pro-agent-configs.nix ] ++ lib.optionals (opencodeBwrapModule != null) [ opencodeBwrapModule ];
      home.username = name;
      home.homeDirectory = "/home/${name}";
      home.stateVersion = "23.11";
      # Доставка бинаря opencode без бандла плагинов/bun во время switch
      # Опционально: можно включить sandboxed wrapper через programs.opencode-bwrap,
      # но он может тащить плагины. Поэтому оставляем только бинарь.
      # programs.opencode-bwrap.enable = lib.mkDefault false;
      home.packages = lib.mkAfter ([ pkgs.opencode ]
        ++ lib.optional (builtins.hasAttr "telega-server" pkgs) pkgs.telega-server);
        pro.emacs = {
          enable = true;
          gui.enable = false;
          providedPackages = [
            "ace-window" "avy" "cape" "consult" "consult-dash" "consult-eglot" "consult-projectile" "consult-yasnippet"
            "corfu" "corfu-posframe" "corfu-terminal" "dash-docs" "eglot" "elfeed" "expand-region" "gptel"
            "eldoc-box" "goto-chg"
            "kind-icon" "magit" "marginalia" "markdown-mode" "nerd-icons" "nerd-icons-ibuffer" "nerd-icons-completion"
            "nix-mode" "orderless" "org" "ob-mermaid" "projectile" "rainbow-delimiters"
            "telega"
            "treemacs" "vertico" "vterm" "yasnippet" "embark-consult" "dash-docs" "consult-dash"
            "multi-vterm" "eshell-toggle" "acapella" "atlas" "shaoline" "tao-theme" "pro-tabs"
            "agent-shell" "agent-shell-hud" "acp" "emcp" "http-server" "shell-maker"
            "treemacs-icons-dired"
            "async" "dash" "embark" "popon" "cond-let" "magit-section" "visual-fill-column"
            "buffer-move" "golden-ratio"
          ];

          extraPackages = let
            piAcp = if builtins.hasAttr "piAcp" pkgs then [ pkgs.piAcp ] else [ ];
            extraEmacs = let
              epkgs = pkgs.emacsPackages;
            in
              []
              ++ (if builtins.hasAttr "tao-theme" epkgs then [ epkgs.tao-theme ] else [ ])
              ++ (if builtins.hasAttr "all-the-icons" epkgs then [ epkgs.all-the-icons ] else [ ])
              ++ (if builtins.hasAttr "pro-tabs" epkgs then [ epkgs.pro-tabs ] else [ ])
              ++ (if builtins.hasAttr "carriage" epkgs then [ epkgs.carriage ] else [ ])
              ++ (if builtins.hasAttr "acapella" epkgs then [ epkgs.acapella ] else [ ])
              ++ (if builtins.hasAttr "atlas" epkgs then [ epkgs.atlas ] else [ ])
              ++ (if builtins.hasAttr "shaoline" epkgs then [ epkgs.shaoline ] else [ ]);
            # Hunspell + русский словарь (см. modules/pro-spellcheck.nix):
            # обёртка pro-hunspell проксирует DICPATH на ru_RU/en_US, чтобы
            # flyspell в Emacs находил словари без ручной настройки.
            spellPackages = lib.optional config.pro.spellcheck.enable
              config.pro.spellcheck.hunspellPackage;
          in piAcp ++ [
            pkgs.emacsPackages.ace-window pkgs.emacsPackages.avy pkgs.emacsPackages.cape pkgs.emacsPackages.consult
            pkgs.emacsPackages.consult-dash pkgs.emacsPackages.consult-eglot pkgs.emacsPackages.consult-projectile pkgs.emacsPackages.consult-yasnippet
            pkgs.emacsPackages.corfu pkgs.emacsPackages.dash-docs pkgs.emacsPackages.consult-dash pkgs.emacsPackages.embark-consult
            pkgs.emacsPackages.eglot pkgs.emacsPackages.elfeed pkgs.emacsPackages.expand-region pkgs.emacsPackages.gptel
            pkgs.emacsPackages.kind-icon pkgs.emacsPackages.magit pkgs.emacsPackages.marginalia pkgs.emacsPackages.markdown-mode pkgs.emacsPackages.nix-mode
            pkgs.emacsPackages.orderless pkgs.emacsPackages.org pkgs.emacsPackages.projectile pkgs.emacsPackages.rainbow-delimiters
            pkgs.emacsPackages.treemacs pkgs.emacsPackages.vertico pkgs.emacsPackages.vterm pkgs.emacsPackages.yasnippet
          ] ++ extraEmacs ++ spellPackages;
        };

        # OpenCode TUI config disabled: no plugins, no generated files.
    };
  }) [ "az" "za" "la" "bo" ]);
}
