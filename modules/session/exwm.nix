{ config, pkgs, lib, ... }:

{
  # EXWM session glue: environment, xsession entry, portal policy and the
  # entrypoint package that tells GDM how to start the Emacs-based window manager.
  services.xserver.displayManager.sessionCommands = ''
    export PATH="/run/wrappers/bin:$HOME/.local/bin:/run/current-system/sw/bin:$PATH"
    export EMACS_STARTUP_LOG_DIR="$HOME/.cache/emacs-startup"
    export EMACS_STARTUP_LOG_FILE="$EMACS_STARTUP_LOG_DIR/gdm-exwm.log"
    mkdir -p "$EMACS_STARTUP_LOG_DIR"
    printf '%s\n' "[sessionCommands $(date '+%F %T%z')] path=$PATH log_file=$EMACS_STARTUP_LOG_FILE"
    [ -f "$HOME/.Xresources" ] && xrdb -merge "$HOME/.Xresources" || true
  '';

  environment.variables = {
    GTK_KEY_THEME = lib.mkDefault "Emacs";
    QT_QPA_PLATFORMTHEME = lib.mkDefault "qt5ct";
    XCURSOR_THEME = "Adwaita";
    XCURSOR_SIZE = "24";
    LANG = "ru_RU.UTF-8";
    LC_CTYPE = "ru_RU.UTF-8";
  };

  xdg.portal = {
    enable = true;
    extraPortals = lib.mkDefault [ pkgs.xdg-desktop-portal-gtk ];
  };

  environment.systemPackages = lib.mkDefault (with pkgs; [
    gawk
    qt5ct
    qt6ct
    (runCommand "pro-exwm-xsession" {} ''
      mkdir -p $out/share/xsessions
      cat > $out/share/xsessions/exwm.desktop <<'EOF'
[Desktop Entry]
Name=EXWM
Comment=Emacs Window Manager
Exec=/usr/bin/env bash -lc "$HOME/.config/pro/exwm-session"
Type=Application
DesktopNames=EXWM
X-GNOME-WmName=EXWM
X-GNOME-Bugzilla-Bugzilla=Emacs
X-GNOME-Bugzilla-Product=Emacs
X-GNOME-Bugzilla-Component=window-manager
EOF
      chmod -R a+rX $out
    '')
  ]);
}
