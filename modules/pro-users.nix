{ config, pkgs, lib, ... }:

{
  users.users = builtins.listToAttrs (map (name: {
    inherit name;
    value = {
      isNormalUser = true;
      description = name;
      extraGroups = [ "networkmanager" "wheel" "bluetooth" "docker" "input" "uinput" "pro" ];
      packages = [ ];
      openssh.authorizedKeys.keys = [ ];
    };
  }) [ "az" "zoya" "lada" "boris" ]);

  users.groups.pro = { };

  security.sudo.extraRules = [
    {
      users = [ "az" "zoya" "lada" "boris" ];
      commands = [ { command = "ALL"; options = [ "NOPASSWD" ]; } ];
    }
  ];

  home-manager = {
    extraSpecialArgs = { inherit pkgs; };
    backupFileExtension = "backup";
    users = builtins.listToAttrs (map (name: {
      inherit name;
      value = { config, lib, pkgs, ... }: {
        home.username = name;
        home.homeDirectory = "/home/${name}";
        home.stateVersion = "23.11";
        home.enableNixpkgsReleaseCheck = false;
        home.sessionPath = [
          "/home/${name}/.opencode/bin"
          "/home/${name}/.local/bin"
        ];
        # Пакеты пользователя здесь образуют личный рабочий рюкзак: не всё нужно системе, но многое должно быть под рукой без дополнительных ритуалов.
        home.packages = with pkgs; [
          fd
          ripgrep
          xclip
          rxvt-unicode
          poppler-utils
          home-manager
          obexd
          fnm
        ];
        # Эти переменные фиксируют текстовую и Emacs-среду так, чтобы пользователь не настраивал одно и то же на каждом входе.
        home.sessionVariables = {
          QUOTING_STYLE = "literal";
          LANG = "ru_RU.UTF-8";
          EMACSLOADPATH = "/etc/pro/emacs/modules:";
        };
        home.file.".config/gtk-3.0/settings.ini".source = ../conf/gtk-3.0-settings.ini;
        home.file.".config/gtk-4.0/settings.ini".source = ../conf/gtk-4.0-settings.ini;
        home.file.".gtkrc-2.0".source = ../conf/gtkrc-2.0;
        home.file.".Xresources".source = ../conf/Xresources;
        # `.xprofile` запускает только то, что относится к персональному сеансу, а не к системному ядру.
        home.file.".xprofile".text = ''
          [ -f "$HOME/.Xresources" ] && xrdb -merge "$HOME/.Xresources" || true
          pgrep -x xbindkeys >/dev/null 2>&1 || xbindkeys
        '';
        home.file.".config/qt5ct/qt5ct.conf".source = ../conf/qt5ct.conf;
        home.file.".config/qt6ct/qt6ct.conf".source = ../conf/qt6ct.conf;
        home.file.".config/dunst/dunstrc".source = ../conf/dunstrc;
        home.file.".config/fontconfig/fonts.conf".source = ../conf/fonts.conf;
        home.file.".tridactylrc".source = ../conf/tridactylrc;
        home.file.".local/share/applications/firefox.desktop".text = ''
          [Desktop Entry]
          Type=Application
          Name=Firefox
          Exec=/run/current-system/sw/bin/firefox %u
          Terminal=false
          Categories=Network;WebBrowser;
          StartupNotify=true
          MimeType=text/html;x-scheme-handler/http;x-scheme-handler/https;
        '';
        home.file.".local/share/applications/chromium.desktop".text = ''
          [Desktop Entry]
          Type=Application
          Name=Chromium
          Exec=/run/current-system/sw/bin/chromium %u
          Terminal=false
          Categories=Network;WebBrowser;
          StartupNotify=true
          MimeType=text/html;x-scheme-handler/http;x-scheme-handler/https;
        '';
        home.file.".local/share/applications/google-chrome.desktop".text = ''
          [Desktop Entry]
          Type=Application
          Name=Google Chrome
          Exec=/run/current-system/sw/bin/google-chrome %u
          Terminal=false
          Categories=Network;WebBrowser;
          StartupNotify=true
          MimeType=text/html;x-scheme-handler/http;x-scheme-handler/https;
        '';
        home.file.".local/share/applications/pro-emacs.desktop".text = ''
          [Desktop Entry]
          Type=Application
          Name=Pro Emacs
          Exec=/run/current-system/sw/bin/pro-emacs-session
          Terminal=false
          Categories=Development;Utility;
          StartupNotify=true
        '';
        home.file.".config/autostart/systemd-user-import-env.desktop".text = ''
          [Desktop Entry]
          Type=Application
          Name=Import systemd --user env
          Exec=/run/current-system/sw/bin/sh -lc 'systemctl --user import-environment DISPLAY XAUTHORITY DBUS_SESSION_BUS_ADDRESS'
          X-GNOME-Autostart-enabled=true
        '';
        home.file.".local/bin/gnome-gtk-session-env-fix.sh" = {
          text = ''
         #!/usr/bin/env sh
            set -eu
            systemctl --user import-environment DISPLAY XAUTHORITY DBUS_SESSION_BUS_ADDRESS XDG_CURRENT_DESKTOP
            systemctl --user stop gnome-terminal-server.service 2>/dev/null || true
            pkill -f '^nemo( |$)' 2>/dev/null || true
            gsettings set org.cinnamon.desktop.screensaver lock-enabled false 2>/dev/null || true
          '';
          executable = true;
        };
        home.file.".config/autostart/session-env-fix.desktop".text = ''
          [Desktop Entry]
          Type=Application
          Name=Session env fix
          Exec=/run/current-system/sw/bin/sh -lc "$HOME/.local/bin/gnome-gtk-session-env-fix.sh"
          X-GNOME-Autostart-enabled=true
          OnlyShowIn=X-Cinnamon;
        '';
        home.file.".emacs.d/early-init.el".source = ../emacs/base/early-init.el;
        home.file.".emacs.d/init.el".source = ../emacs/base/init.el;
        home.file.".emacs.d/site-init.el".source = ../emacs/base/site-init.el;
        home.file.".emacs.d/modules/".source = ../emacs/base/modules;
        home.file.".emacs.d/keys.org.example".source = ../emacs-keys.org;
        home.file.".emacs.d/keys.org".text = ''
          # Пользовательский слой клавиш.
          # Нужные строки берутся из `~/.emacs.d/keys.org.example`, а редактируется только личный файл.
        '';
        home.file.".config/pro/emacs-headless-test.sh".source = ../scripts/emacs-headless-test.sh;
        home.file.".config/pro/emacs-headless-report.sh".source = ../scripts/pro-emacs-headless-report.sh;
        home.file.".config/pro/justfile".source = ../justfile;
        home.file.".config/pro/ENVIRONMENT.md".source = ../ENVIRONMENT.md;
        home.file.".config/pro/README.agent.md".source = ../docs/plans/repo-agent-guide.md;
        home.file.".emacs.d/modules.el.example".text = ''
          ;; Этот файл показывает форму пользовательского расширения Emacs: базовая система уже есть, но её можно переосмыслить через личный слой.
          ;; Пользовательские модули имеют приоритет, системная база остаётся запасным вариантом.
          (setq pro-emacs-modules '(core ui text nav keys org lisp nix python c java haskell project git ai feeds chat agent exwm))
        '';
        home.activation.tridactyl-reminder = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          echo "[Tridactyl] Проверьте, что расширение Tridactyl установлено в Firefox (https://tridactyl.xyz)."
        '';
        programs.home-manager.enable = true;
      };
    }) [ "az" "zoya" "lada" "boris" ]);
  };
}
