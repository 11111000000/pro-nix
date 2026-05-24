{ pkgs, lib, ... }:

{
  # Sway — современный Wayland-tile WM для GDM-сессии.
  # Модуль публикует только session entry и минимальный набор пакетов панели.
  services.displayManager.sessionPackages = lib.mkDefault [
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

  environment.systemPackages = lib.mkDefault (with pkgs; [
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
  ]);
}
