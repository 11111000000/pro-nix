{ pkgs, lib, ... }:

{
  # i3 — X11 tile WM для GDM-сессии.
  # Модуль публикует session entry и минимальный набор пакетов панели.
  services.displayManager.sessionPackages = [
    (pkgs.runCommand "pro-i3-session" { passthru.providedSessions = [ "i3" ]; } ''
      mkdir -p $out/share/xsessions
      cat > $out/share/xsessions/i3.desktop <<'EOF'
[Desktop Entry]
Name=i3
Comment=improved dynamic tiling window manager
Exec=/usr/bin/env bash -lc "exec i3"
Type=Application
DesktopNames=i3
EOF
      chmod -R a+rX $out
    '')
  ];

  # Package list uses plain assignment (not lib.mkDefault) so it is always
  # concatenated with lists from other imported modules.
  environment.systemPackages = with pkgs; [
    i3
    i3status
    dmenu
    xterm
    dex
    feh
    dunst
    polybar
  ];
}
