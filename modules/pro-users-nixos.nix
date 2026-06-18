{ config, lib, pkgs, opencodeBwrapModule ? null, piPkg, ... }:

{
  # Forward piPkg from NixOS specialArgs into home-manager module scope.
  # pro-agent-configs.nix uses it to symlink the built-in subagent extension
  # from pi-coding-agent's nix store path. Set in BOTH the NixOS scope and
  # each home-manager user scope to handle the two evaluation contexts.
  _module.args.piPkg = piPkg;

  home-manager.users = builtins.listToAttrs (map (name: {
    inherit name;
    value = {
      imports = [ ../emacs/home-manager.nix ./opencode-tui.nix ./pro-agent-configs.nix ] ++ lib.optionals (opencodeBwrapModule != null) [ opencodeBwrapModule ];
      _module.args.piPkg = piPkg;
      home.username = name;
      home.homeDirectory = "/home/${name}";
      home.stateVersion = "23.11";
      # Доставка бинаря opencode без бандла плагинов/bun во время switch
      # Опционально: можно включить sandboxed wrapper через programs.opencode-bwrap,
      # но он может тащить плагины. Поэтому оставляем только бинарь.
      # programs.opencode-bwrap.enable = lib.mkDefault false;
      home.packages = lib.mkAfter ([ pkgs.opencode pkgs.docker pkgs.docker-compose pkgs.docker-credential-helpers ]
        ++ lib.optional (builtins.hasAttr "telega-server" pkgs) pkgs.telega-server);
        pro.emacs = {
          enable = true;
          # GUI-слой Emacs-профиля (X-сессия, gtk/qt-конфиги,
          # ~/.config/pro/exwm-session) включается через pro-users.nix
          # в NixOS-eval, чтобы прочитать config.pro.profiles.exwmMinimal.enable
          # (NixOS-опция недоступна в HM-eval). На TUI-only хостах /
          # Termux остаётся default (false).
          #
          # providedPackages здесь — **plain assignment**, полностью
          # перезаписывает default в emacs/core.nix. Если что-то нужно
          # добавить — добавляйте сюда, иначе core.nix default
          # игнорируется. Особо критично:
          #   - exwm + xelb — без них pro-exwm-start-session падает на
          #     `(require 'exwm)`, EXWM как WM не активируется,
          #     пользователь видит обычный Emacs. Раньше exwm/xelb были
          #     доступны через `~/.config/emacs/elpa/exwm-*/` после ручной
          #     установки; это хрупко и было потеряно при чистке elpa/.
          #   - exwm-x — переименованный exwm-xim (nixpkgs ≥ 23.x);
          #     нужен для IME в X-приложениях (Firefox и пр.).
          #   - exwm-systemtray и exwm-xim — старые имена, в nixpkgs 25.11
          #     их нет; pro-exwm.el корректно игнорирует через condition-case.
          providedPackages = [
            "ace-window" "avy" "cape" "consult" "consult-dash" "consult-eglot" "consult-projectile" "consult-yasnippet"
            "corfu" "corfu-posframe" "corfu-terminal" "dash-docs" "docker" "eglot" "elfeed" "expand-region" "gptel"
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
            # EXWM stack (nixpkgs 25.11). Эти пакеты попадают в
            # EMACSLOADPATH через emacs/core.nix:allLoadPaths, и в
            # home.packages через availableProvidedNix. Без них
            # (require 'exwm) падает в pro-exwm-start-session.
            "exwm" "xelb" "exwm-x"
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
            pkgs.emacsPackages.treemacs pkgs.emacsPackages.vertico pkgs.emacsPackages.vterm pkgs.emacsPackages.yasnippet
            pkgs.emacsPackages.docker
            pkgs.emacsPackages.elisp-refs
          ] ++ lib.optional (builtins.hasAttr "emacsPackages" pkgs && builtins.hasAttr "http-server" pkgs.emacsPackages)
              pkgs.emacsPackages.http-server
            ++ extraEmacs ++ spellPackages;
        };

        # OpenCode TUI config disabled: no plugins, no generated files.
    };
  }) [ "az" "za" "la" "bo" ]);
}
