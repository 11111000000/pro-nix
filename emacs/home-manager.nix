{ config, lib, pkgs, emacsPkg ? pkgs.emacs, opencode_from_release ? null, ... }:

let
  cfg = config.pro.emacs;
  defaultModules = [ "core" "ui" "packages" "package-bootstrap" "text" "nav" "keys" "org" "lisp" "python" "c" "java" "haskell" "project" "git" "ai" "feeds" "chat" "agent" "exwm" ];
  defaultModulesText = lib.concatStringsSep " " defaultModules;
  hmPackages = with pkgs; [ fd ripgrep home-manager fnm git ];
  guiPackages = with pkgs; [ xclip rxvt-unicode obexd ];

  # Обзор модулей Emacs
  # - core, ui, packages: фундаментальные компоненты для загрузки окружения.
  # - lisp, python, haskell: языковые интеграции и среды разработки.
  # - ai, agent, chat: модули, интегрирующие агентов и LLM через внешние сервисы
  #   или локальные двоичные файлы (см. ollama в system-packages.nix).
  portableFiles = {
    home.file.".config/emacs/early-init.el".source = ../emacs/base/early-init.el;
    home.file.".config/emacs/init.el".source = ../emacs/base/init.el;
    home.file.".config/emacs/site-init.el".source = ../emacs/base/site-init.el;
    home.file.".config/emacs/modules".source = ../emacs/base/modules;
    home.file.".config/emacs/keys.org.example".source = ../emacs-keys.org;
    home.file.".config/emacs/modules.el.example".text = ''
      ;; Пользовательская форма списка модулей.
      (setq pro-emacs-modules '(${defaultModulesText}))
      (setq pro-emacs-base-modules pro-emacs-modules)
    '';
    # Примечание: файлы с суффиксом .example являются шаблонами. Редактируйте
    # их в домашней директории пользователя, не изменяя системный шаблон.

    home.file.".config/pro/emacs-headless-test.sh".source = ../scripts/emacs-headless-test.sh;
    home.file.".config/pro/emacs-headless-report.sh".source = ../scripts/emacs-headless-report.sh;
    home.file.".config/pro/justfile".source = ../justfile;
    home.file.".config/pro/ENVIRONMENT.md".source = ../ENVIRONMENT.md;
    home.file.".config/pro/README.agent.md".source = ../docs/plans/repo-agent-guide.md;

    # NOTE: We provide only the example template `keys.org.example`.
    # The actual user file `~/.config/emacs/keys.org` is intentionally
    # not created by default so that users explicitly copy/instantiate
    # it from the example. This prevents accidental commits of a
    # concrete keys file and keeps user overrides local.
  };

  guiFiles = {
    home.file.".config/gtk-3.0/settings.ini".source = ../conf/gtk-3.0-settings.ini;
    home.file.".config/gtk-4.0/settings.ini".source = ../conf/gtk-4.0-settings.ini;
    home.file.".gtkrc-2.0".source = ../conf/gtkrc-2.0;
    home.file.".Xresources".source = ../conf/Xresources;
    home.file.".config/qt5ct/qt5ct.conf".source = ../conf/qt5ct.conf;
    home.file.".config/qt6ct/qt6ct.conf".source = ../conf/qt6ct.conf;
    home.file.".config/dunst/dunstrc".source = ../conf/dunstrc;
    home.file.".config/fontconfig/fonts.conf".source = ../conf/fonts.conf;
    home.file.".tridactylrc".source = ../conf/tridactylrc;

    home.file.".xprofile".text = ''
      [ -f "$HOME/.Xresources" ] && xrdb -merge "$HOME/.Xresources" || true
      pgrep -x xbindkeys >/dev/null 2>&1 || xbindkeys
    '';

    home.file.".config/autostart/systemd-user-import-env.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Import systemd --user env
      Exec=${config.home.homeDirectory}/.local/bin/pro-emacs-env-fix.sh
      X-GNOME-Autostart-enabled=true
    '';

    home.file.".local/bin/pro-emacs-env-fix.sh" = {
      text = ''
        #!/usr/bin/env sh
        set -eu
        systemctl --user import-environment DISPLAY XAUTHORITY DBUS_SESSION_BUS_ADDRESS XDG_CURRENT_DESKTOP
        systemctl --user stop gnome-terminal-server.service 2>/dev/null || true
      '';
      executable = true;
    };

    home.file.".config/autostart/session-env-fix.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Session env fix
      Exec=${config.home.homeDirectory}/.local/bin/pro-emacs-env-fix.sh
      X-GNOME-Autostart-enabled=true
      OnlyShowIn=X-Cinnamon;
    '';

    home.file.".local/share/applications/pro-emacs.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Pro Emacs
      Exec=${config.home.homeDirectory}/.config/pro/pro-emacs-session
      Terminal=false
      Categories=Development;Utility;
      StartupNotify=true
    '';

    home.file.".local/share/xsessions/exwm.desktop".text = ''
      [Desktop Entry]
      Name=EXWM
      Comment=Emacs Window Manager
      Exec=${config.home.homeDirectory}/.config/pro/exwm-session
      Type=Application
      DesktopNames=EXWM
      X-GNOME-WmName=EXWM
      X-GNOME-Bugzilla-Bugzilla=Emacs
      X-GNOME-Bugzilla-Product=Emacs
      X-GNOME-Bugzilla-Component=window-manager
    '';

    home.file.".config/pro/pro-emacs-session" = {
      text = ''
        #!/usr/bin/env bash
        exec ${emacsPkg}/bin/emacs --init-directory "$HOME/.config/emacs" "$@"
      '';
      executable = true;
    };

    # opencode integration removed. See docs/opencode-integration.md.

    home.file.".config/pro/exwm-session" = {
      text = ''
        #!/usr/bin/env bash
        # Запуск вспомогательных приложений и переменных среды для EXWM.
        LOG_DIR="$HOME/.cache/emacs-startup"
        LOG_FILE="$LOG_DIR/gdm-exwm.log"
        mkdir -p "$LOG_DIR"
        exec >>"$LOG_FILE" 2>&1

        printf '%s\n' "[exwm-session-start $(date '+%F %T%z')] begin log_file=$LOG_FILE"
        printf '%s\n' "[exwm-session-start $(date '+%F %T%z')] pwd=$PWD user=$USER display='(echo $DISPLAY)'\ndesktop_session='(echo $DESKTOP_SESSION)'\nxdg_session='(echo $XDG_SESSION_TYPE)'\nenv EMACS_STARTUP_LOG_DIR='(echo $EMACS_STARTUP_LOG_DIR)'\nEMACS_STARTUP_LOG_FILE='(echo $EMACS_STARTUP_LOG_FILE)'"
        printf '%s\n' "[exwm-session-start $(date '+%F %T%z')] pwd=$PWD user=$USER"
        printf '%s\n' "[exwm-session-start $(date '+%F %T%z')] env display=$DISPLAY desktop_session=$DESKTOP_SESSION xdg_session=$XDG_SESSION_TYPE"

        eval $(ssh-agent -s)
        export SSH_AUTH_SOCK
        # Ensure nix-ld is not used inside EXWM/Emacs session by clearing preload.
        export NIX_LD_PRELOAD=""
        xset -b
        xhost +SI:localuser:$USER
        xhost +SI:localuser:root

        export QT_QPA_PLATFORMTHEME=qt5ct
        export XMODIFIERS=@im=exwm-xim
        export GTK_IM_MODULE=xim
        export QT_IM_MODULE=xim
        export CLUTTER_IM_MODULE=xim
        export GTK_KEY_THEME=Emacs

        export LSP_USE_PLISTS=true

        xsetroot -cursor_name left_ptr
        export VISUAL=emacsclient
        export EDITOR="$VISUAL"

        xrdb -merge ~/.Xresources

        export XDG_CURRENT_DESKTOP=EXWM
        printf '%s\n' "[exwm-session-start $(date '+%F %T%z')] importing env and launching emacs"
        systemctl --user import-environment DISPLAY XAUTHORITY PATH DBUS_SESSION_BUS_ADDRESS XDG_RUNTIME_DIR XDG_CURRENT_DESKTOP
        printf '%s\n' "[exwm-session-start $(date '+%F %T%z')] exec systemd-run emacs"
        exec /run/current-system/sw/bin/systemd-run --user --scope -p MemoryMax=2G -p MemoryHigh=1800M -p CPUQuota=120% -p CPUWeight=200 -- ${emacsPkg}/bin/emacs --init-directory "$HOME/.config/emacs"
      '';
      executable = true;
    };
  };
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
      # Default set of packages we prefer to provide via Nix to ensure
      # reproducible load-paths and avoid runtime auto-installs.
      default = [ "magit" "consult" "vertico" "orderless" "marginalia" "gptel" "agent-shell" "consult-dash" "dash-docs" "consult-eglot" "consult-yasnippet" "corfu" "cape" "kind-icon" "avy" "expand-region" "yasnippet" "projectile" "treemacs" "consult-projectile" "elfeed" "eglot" "rainbow-delimiters" "nix-mode" "mmm-mode" "org" "vterm" "ace-window" ];
      description = "List of Emacs package names (symbols) provided by Nix and exposed to the runtime as pro-packages-provided-by-nix.";
    };

    defaultModules = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = defaultModules;
      description = "Модули, которые Emacs загружает по умолчанию.";
    };
  };

  config = let
    # Determine which of the configured providedPackages are present
    # in pkgs.emacsPackages. We will install the available ones into
    # the user's profile so Emacs finds them on the load-path.
    providedList = cfg.providedPackages;
    availableProvided = lib.filter (p: lib.hasAttr p pkgs.emacsPackages) providedList;
    # Use builtins.getAttr to safely lookup attributes by name.
    availableProvidedNix = map (p: builtins.getAttr p pkgs.emacsPackages) availableProvided;
    missingProvided = lib.filter (p: !(lib.hasAttr p pkgs.emacsPackages)) providedList;
  in lib.mkIf cfg.enable (lib.mkMerge [
    {
      programs.home-manager.enable = true;

      # Ensure opencode is available in each user's profile when a
      # deterministic opencode derivation is provided by the flake via
      # specialArgs (opencode_from_release). This makes opencode available
      # under ~/.nix-profile/bin for all users and removes dependency on
      # session PATH propagation. Keep the change minimal: only add the
      # opencode derivation when it's present.
      home.packages = hmPackages
        ++ (if opencode_from_release != null then [ opencode_from_release ] else [])
        ++ cfg.extraPackages ++ availableProvidedNix ++ lib.optionals cfg.gui.enable guiPackages;

      # Включаем автоустановку пакетов в рантайме (MELPA/ELPA fallback)
      # по явной политике профиля. Это позволяет подтянуть пакеты,
      # отсутствующие в текущем наборе Nix, не ломая первый запуск.
      home.sessionVariables = {
        QUOTING_STYLE = "literal";
        LANG = "ru_RU.UTF-8";
        EMACSLOADPATH = "${lib.concatStringsSep ":" (map (pkg: "${pkg}/share/emacs/site-lisp") availableProvidedNix)}:${config.home.homeDirectory}/.config/emacs/modules:";
        PRO_PACKAGES_AUTO_INSTALL = "1";
      };

      # Report which provided packages were satisfied by Nix at activation
      home.activation.pro-emacs-provided-packages-report = ''
        echo "pro-emacs: provided packages available: ${lib.concatStringsSep " " availableProvided}" || true
        echo "pro-emacs: provided packages missing in nix: ${lib.concatStringsSep " " missingProvided}" || true
      '';

      # Copy repo-provided templates from /etc/skel/pro-templates into the
      # user's home if they do not already exist. This runs as part of each
      # user's home-manager activation and uses cp -n to avoid overwriting.
      home.activation.pro-templates-copy = ''
        #!/bin/sh -e
        [ -d /etc/skel/pro-templates ] || exit 0
        cp -r -n /etc/skel/pro-templates/. "$HOME/" || true
      '';

      # Ensure a user-writable Emacs custom file exists so Emacs does not
      # attempt to write customization into a system-provided readonly init
      # (e.g. an init in /nix/store). Create it only if it does not already
      # exist to avoid overwriting user-managed customizations.
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
      '';

      # Генерируем runtime-список только из реально доступных Nix-пакетов,
      # чтобы pro-packages не считал отсутствующие пакеты "гарантированными".
      home.file.".config/emacs/provided-packages.el".text = let
        pkgsList = availableProvided;
        sexp = lib.concatStringsSep " " (map (p: p) pkgsList);
      in ''(setq pro-packages-provided-by-nix '(${sexp}))'';
    }
    portableFiles
    (lib.mkIf cfg.gui.enable guiFiles)
  ]);
}
