{ pkgs, ... }:

with pkgs;

{
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
    pcmanfm
    xfce.thunar
    pavucontrol
    copyq
    dunst
    flameshot
    playerctl
  ];
}
