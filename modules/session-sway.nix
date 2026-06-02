{ pkgs, lib, ... }:

{
  # Sway — современный Wayland-tile WM для GDM-сессии.
  # Модуль публикует только session entry и минимальный набор пакетов панели.
  services.displayManager.sessionPackages = [
    (pkgs.runCommand "pro-sway-session" { passthru.providedSessions = [ "sway" ]; } ''
      mkdir -p $out/share/wayland-sessions
      cat > $out/share/wayland-sessions/sway.desktop <<'EOF'
[Desktop Entry]
Name=Sway
Comment=Wayland compositor and window manager
Exec=/usr/bin/env bash -lc "exec sway"
Type=Application
DesktopNames=Sway
EOF
      chmod -R a+rX $out
    '')
  ];

  # Package list uses plain assignment (not lib.mkDefault) so it is always
  # concatenated with lists from other imported modules.
  environment.systemPackages = with pkgs; [
    sway
    waybar
    mako
    swaybg
    swaylock
    swayidle
    wl-clipboard
    wofi
    grim
    slurp
  ];
}
