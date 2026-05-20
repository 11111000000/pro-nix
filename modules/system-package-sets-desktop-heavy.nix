{ pkgs, ... }:

with pkgs;

{
  # Heavy desktop apps are opt-in by design. They do not belong to a minimal
  # EXWM host, but they must remain available so huawei can reproduce its
  # current richer workstation surface.
  desktopHeavyPackages = [
    chromium
    firefox
    telegram-desktop
    element-desktop
    jami
    ffmpeg-full
    deluge
    steam
    steam-run
    pavucontrol
    copyq
    dunst
    flameshot
    playerctl
  ];
}
