{ pkgs, ... }:

with pkgs;

{
  exwmPackages = [
    xorg.xset
    xorg.xhost
    xorg.setxkbmap
    xorg.xsetroot
    wmname
    xbindkeys
    xdotool
    xclip
    xauth
  ];
}
