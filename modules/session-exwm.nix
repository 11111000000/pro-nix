{ config, pkgs, lib, emacsPkg ? pkgs.emacs, ... }:

{
  # EXWM session glue: environment, xsession entry, portal policy and the
  # entrypoint package that tells GDM how to start the Emacs-based window manager.
  services.xserver.displayManager.sessionCommands = ''
    export PATH="/run/wrappers/bin:$HOME/.local/bin:/run/current-system/sw/bin:$PATH"
    export EMACS_STARTUP_LOG_DIR="$HOME/.cache/emacs-startup"
    export EMACS_STARTUP_LOG_FILE="$EMACS_STARTUP_LOG_DIR/gdm-exwm.log"
    mkdir -p "$EMACS_STARTUP_LOG_DIR"
    printf '%s\n' "[sessionCommands $(date '+%F %T%z')] path=$PATH log_file=$EMACS_STARTUP_LOG_FILE"
    # Merge Xresources from the system location first, then the user override
    # if present.  The system file is deployed by configuration.nix via
    # environment.etc."X11/Xresources", which is the only guaranteed location
    # when home-manager is not active for this user.
    [ -r /etc/X11/Xresources ] && xrdb -merge /etc/X11/Xresources || true
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

  services.displayManager.sessionPackages = [
    (pkgs.runCommand "pro-exwm-xsession" { passthru.providedSessions = [ "exwm" ]; } ''
      mkdir -p $out/share/xsessions $out/share/wayland-sessions
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
      ln -s ../xsessions/exwm.desktop $out/share/wayland-sessions/exwm.desktop
      chmod -R a+rX $out
    '')
  ];

  # Package list uses plain assignment (not lib.mkDefault) so it is always
  # concatenated with lists from other imported modules.
  environment.systemPackages = with pkgs; [
    gawk
    xorg.xset
    xorg.xhost
    xorg.setxkbmap
    xorg.xsetroot
    wmname
    xbindkeys
    xdotool
    xclip
    xauth
    xvfb-run
  ];
}
