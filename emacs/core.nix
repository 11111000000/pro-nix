{ config, lib, pkgs, emacsPkg ? pkgs.emacs, ... }:

let
  cfg = config.pro.emacs;
  defaultModules = [
    "core" "ui" "packages" "package-bootstrap"
    "text" "nav" "keys" "org" "lisp" "python" "c" "java" "haskell"
    "project" "git" "ai" "feeds" "chat" "telega" "agent" "exwm"
    "ui-tty" "ui-improvements" "ui-icons" "ui-fringes" "ui-modeline"
    "history" "dashboard" "help" "windows-popups" "spell" "clipboard"
  ];
  defaultModulesText = lib.concatStringsSep " " defaultModules;
  treeSitterBundle = pkgs.runCommand "pro-emacs-tree-sitter-langs" { nativeBuildInputs = [ pkgs.gnutar ]; } ''
    set -euo pipefail
    mkdir -p "$out"
    tar -xzf ${pkgs.fetchurl {
      url = "https://github.com/emacs-tree-sitter/tree-sitter-langs/releases/download/0.13.49/tree-sitter-grammars.x86_64-unknown-linux-gnu.v0.13.49.tar.gz";
      sha256 = "HCxf8X/HJpTZpT7aQOqNscC9waiaVUr7RJannlExngA=";
    }} -C "$out"
  '';
  hmPackages = with pkgs; [ fd ripgrep home-manager fnm git ];
in
{
  options.pro.emacs = {
    enable = lib.mkEnableOption "portable Emacs profile";

    gui.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Включает GUI-слой Emacs-профиля.";
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Дополнительные пакеты для Emacs-профиля.";
    };

    providedPackages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "magit" "consult" "vertico" "vertico-sort" "orderless" "marginalia" "gptel" "consult-dash" "dash-docs" "consult-eglot" "consult-yasnippet" "corfu" "cape" "kind-icon" "avy" "expand-region" "yasnippet" "projectile" "treemacs" "consult-projectile" "elfeed" "eglot" "rainbow-delimiters" "nix-mode" "markdown-mode" "mmm-mode" "org" "ob-mermaid" "vterm" "multi-vterm" "eshell-toggle" "ace-window" "undo-tree" "haskell-mode" "haskell-snippets" "which-key" "which-key-posframe" "eldoc-box" "keyfreq" "helpful" "popper" "buffer-expose" "buffer-move" "golden-ratio" "embark" "embark-consult" "exwm" "xelb" "agent-shell" "agent-shell-hud" "acp" "emcp" "telega" "transient" "visual-fill-column" "pro-tabs" "goto-chg" "docker" ];
    };

    defaultModules = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = defaultModules;
      description = "Модули, которые Emacs загружает по умолчанию.";
    };
  };

  config = let
    providedList = cfg.providedPackages;
    availableProvided = lib.filter (p: lib.hasAttr p pkgs.emacsPackages) providedList;
    availableProvidedNix = map (p: builtins.getAttr p pkgs.emacsPackages) availableProvided;
    missingProvided = lib.filter (p: !(lib.hasAttr p pkgs.emacsPackages)) providedList;
  in lib.mkIf cfg.enable {
    programs.home-manager.enable = true;

    home.packages = hmPackages ++ cfg.extraPackages ++ availableProvidedNix;

    home.sessionVariables = let
      # For each provided package, collect every directory under its
      # share/emacs/site-lisp/ that contains .el files directly. Covers all
      # three Emacs-package layouts we have in the repo without per-package
      # special-casing:
      #   1. flat         — site-lisp/agent-shell-hud.el
      #   2. local subdir — site-lisp/atlas/atlas.el
      #   3. nixpkgs elpa — site-lisp/elpa/gptel-20251007.257/gptel.el
      # Recursion is bounded by directory nesting in the store path (≤ 3 in
      # practice). readDir is wrapped in tryEval so a missing site-lisp/ in
      # a derivation does not abort the eval.
      collectElDirs = path:
        let exists = (builtins.tryEval (builtins.pathExists path));
        in if !(exists.success && exists.value) then [ ]
           else
             let contents = (builtins.tryEval (builtins.readDir path)); in
             if !contents.success then [ ]
             else
               let
                 d = contents.value;
                 names = lib.attrNames d;
                 hasEl = builtins.any (n: lib.hasSuffix ".el" n) names;
                 subdirs = lib.filter
                   (n: (d.${n} or null) == "directory")
                   names;
                 recursed = lib.concatMap
                   (n: collectElDirs "${path}/${n}")
                   subdirs;
               in lib.optional hasEl path ++ recursed;
      pkgLoadPaths = pkg: collectElDirs "${pkg}/share/emacs/site-lisp";
      allLoadPaths = lib.concatMap pkgLoadPaths availableProvidedNix;
    in {
      QUOTING_STYLE = "literal";
      LANG = "ru_RU.UTF-8";
      EMACSLOADPATH = lib.concatStringsSep ":" (lib.filter (s: s != "") ([
        (lib.concatStringsSep ":" allLoadPaths)
        "${config.home.homeDirectory}/.config/emacs/modules"
      ]));
      # Автоустановка пакетов из MELPA по умолчанию выключена. Emacs стартует
      # на основе Nix-профиля (см. EMACSLOADPATH выше). Если что-то отсутствует,
      # пользователь запускает `M-x pro-package-bootstrap-install-targets' (C-c P a).
      # Чтобы вернуть автоустановку, задайте в ~/.config/home-manager/home.nix:
      #   home.sessionVariables.PRO_PACKAGES_AUTO_INSTALL = "1";
      PRO_PACKAGES_AUTO_INSTALL = "0";
    };

    home.activation.pro-emacs-provided-packages-report = ''
      echo "pro-emacs: provided packages available: ${lib.concatStringsSep " " availableProvided}" || true
      echo "pro-emacs: provided packages missing in nix: ${lib.concatStringsSep " " missingProvided}" || true
    '';

    home.activation.pro-templates-copy = ''
      #!/bin/sh -e
      [ -d /etc/skel/pro-templates ] || exit 0
      cp -r -n /etc/skel/pro-templates/. "$HOME/" || true
    '';

    home.activation.pro-emacs-create-custom = ''
      #!/bin/sh -e
      mkdir -p "$HOME/.config/emacs"
      mkdir -p "$HOME/.local/state/pro-emacs"
      mkdir -p "$HOME/.cache/pro-emacs"
      if [ ! -f "$HOME/.config/emacs/custom.el" ]; then
        cat > "$HOME/.config/emacs/custom.el" <<'EOF'
;;; custom.el --- auto-generated by pro-nix home-manager activation
;; This file is intended to hold Emacs Customize settings for the user.
;; It is safe to edit; home-manager will not overwrite it.
;; -*- lexical-binding: t; -*-

(provide 'user-custom)
EOF
      fi
      # Activation runs as root under `nixos-rebuild switch', so anything
      # we just created or rewrote above is owned by root. Hand ownership
      # back to the invoking user so subsequent Emacs sessions do not see
      # files inside their own $HOME owned by another user.
      target_user="''${SUDO_USER:-''${USER:-$(id -un)}}"
      target_group="''${SUDO_GID:-$(id -g)}"
      if [ -n "$target_user" ] && [ "$target_user" != "root" ]; then
        chown "$target_user:$target_group" \
          "$HOME/.config/emacs" \
          "$HOME/.config/emacs/custom.el" \
          "$HOME/.local/state/pro-emacs" \
          "$HOME/.cache/pro-emacs" || true
      fi
    '';

    home.activation.pro-emacs-install-treesitter = ''
      #!/bin/sh -e
      TS_DIR="$HOME/.config/emacs/tree-sitter"
      required_libs="libtree-sitter-typescript.so libtree-sitter-tsx.so"

      mkdir -p "$TS_DIR"

      for f in $required_libs; do
        if [ -f "$TS_DIR/$f" ]; then
          continue
        fi

        if [ -f "${treeSitterBundle}/$f" ]; then
          cp -f "${treeSitterBundle}/$f" "$TS_DIR/$f"
          continue
        fi

        found=$(find "${treeSitterBundle}" -type f -name "$f" -print -quit)
        if [ -n "$found" ]; then
          cp -f "$found" "$TS_DIR/$f"
          continue
        fi

        echo "pro-emacs: missing required tree-sitter grammar: $f" >&2
      done

      for f in $required_libs; do
        if [ ! -f "$TS_DIR/$f" ]; then
          echo "pro-emacs: tree-sitter bootstrap finished without $f; Emacs may keep using fallback parsing" >&2
          exit 0
        fi
      done

      echo "pro-emacs: installed tree-sitter grammars to $TS_DIR"
    '';

    home.file.".config/emacs/early-init.el".source = ../emacs/base/early-init.el;
    home.file.".config/emacs/init.el".source = ../emacs/base/init.el;
    home.file.".config/emacs/site-init.el".source = ../emacs/base/site-init.el;
    home.file.".config/emacs/modules".source = ../emacs/base/modules;
    home.file.".config/emacs/modules.el.example".text = ''
      ;; Пользовательская форма списка модулей.
      (setq pro-emacs-modules '(${defaultModulesText}))
      (setq pro-emacs-base-modules pro-emacs-modules)
    '';
    home.file.".config/emacs/keys.org.example".source = ../emacs-keys.org;
    home.file.".config/emacs/provided-packages.el".text = let
      sexp = lib.concatStringsSep " " availableProvided;
    in ''(setq pro-packages-provided-by-nix '(${sexp}))'';
  };
}
