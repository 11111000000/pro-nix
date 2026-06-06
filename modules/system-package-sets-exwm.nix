{ pkgs, ... }:

with pkgs;

{
  exwmPackages = [
    xorg.xset
    xorg.xhost
    xorg.setxkbmap
    xorg.xsetroot
    wmname
    xdotool
    xclip
    xauth
    networkmanagerapplet
    blueman
    obexd
    bluez
    feh
    xterm
    scrot
    udiskie
    pasystray
    libnotify
    volumeicon
    caffeine-ng
    redshift
    alsa-ucm-conf
    xorg.xcursorthemes
    pkgs.adwaita-icon-theme
    snixembed
    evince
    zathura
    # Utility to emergency-kill Emacs daemon
    (writeShellScriptBin "emacs-panic" ''
      pkill -INT -u "$USER" -x emacs >/dev/null 2>&1 || pkill -INT -u "$USER" -f 'emacs.*daemon' >/dev/null 2>&1 || true
    '')
  ];
}
