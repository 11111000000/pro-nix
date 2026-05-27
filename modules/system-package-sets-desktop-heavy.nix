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
    # Browser wrappers with memory limits via systemd-run
    (writeShellScriptBin "chromium" ''
      exec systemd-run --user --scope -p MemoryMax=4500M -p MemoryHigh=4G -p CPUQuota=90% -- ${pkgs.chromium}/bin/chromium "$@"
    '')
    (writeShellScriptBin "firefox" ''
      exec systemd-run --user --scope -p MemoryMax=2500M -p MemoryHigh=2G -p CPUQuota=90% -- ${pkgs.firefox}/bin/firefox "$@"
    '')
  ];
}
