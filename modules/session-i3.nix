{ pkgs, lib, ... }:

let
  # Single source of truth: conf/i3-config.in читается и здесь
  # (system-wide /etc/i3/config) и в emacs/exwm.nix (per-user
  # ~/.config/i3/config). Биндинги синхронизированы с sway/EXWM
  # (Mod4+h/j/k/l для focus/move, Mod4+Space для app launcher).
  i3Config = builtins.readFile ../conf/i3-config.in;

  # Polybar — status bar для i3. Конфиг inline (только системный уровень,
  # без per-user override — polybar не критичен для UX, и без него i3
  # работает; статус-бар просто не показывается).
  polybarConfig = ''
    ; polybar config — pro-nix default (modules/session-i3.nix).
    [colors]
    background = #1d1f21
    foreground = #c5c8c6
    alert = #cc6666
    underline = #c5c8c6

    [bar/example]
    width = 100%
    height = 24
    background = #1d1f21
    foreground = #c5c8c6
    modules-left = i3
    modules-right = pulseaudio memory cpu date

    [module/i3]
    type = internal/i3
    format = <label-state>
    label-focused = %name
    label-unfocused = %name
    label-visible = %name
    label-focused-foreground = #f0c674
    label-focused-background = #1d1f21
    label-focused-underline = #f0c674
    label-focused-padding = 2

    [module/pulseaudio]
    type = internal/pulseaudio
    format-volume = <ramp-volume> <label-volume>

    [module/memory]
    type = internal/memory
    format = <label>
    label = %percentage_used%%

    [module/cpu]
    type = internal/cpu
    format = <label>
    label = %percentage%%

    [module/date]
    type = internal/date
    interval = 5
    date = %Y-%m-%d
    time = %H:%M:%S
    format = <label>
    label = %date %time
  '';
in

{
  # i3 — X11 tile WM. Запускаем в среде с явными XDG-переменными, иначе
  # некоторые GTK-аппы (gvfs, xdg-desktop-portal) не понимают, в какой
  # DE они работают.
  services.displayManager.sessionPackages = [
    (pkgs.runCommand "pro-i3-session" { passthru.providedSessions = [ "i3" ]; } ''
      mkdir -p $out/share/xsessions
      cat > $out/share/xsessions/i3.desktop <<'EOF'
[Desktop Entry]
Name=i3
Comment=improved dynamic tiling window manager
Exec=/usr/bin/env bash -lc "exec env XDG_CURRENT_DESKTOP=i3 XDG_SESSION_DESKTOP=i3 i3"
Type=Application
DesktopNames=i3
EOF
      chmod -R a+rX $out
    '')
  ];

  # System-wide fallback ~/.config/i3/config. i3 ищет сначала
  # $XDG_CONFIG_HOME/i3/config, потом /etc/i3/config. Per-user копия
  # в ~/.config/i3/config создаётся home-manager-ом (см. emacs/exwm.nix);
  # per-user override выигрывает. Здесь — fallback для greeter.
  environment.etc."i3/config".text = i3Config;

  # Polybar (status bar для i3) — только системный уровень.
  environment.etc."polybar/config.ini".text = polybarConfig;

  # Package list uses plain assignment (not lib.mkDefault) so it is always
  # concatenated with lists from other imported modules.
  # NB: i3-nagbar — это бинарь внутри derivation `i3` (${i3}/bin/i3-nagbar),
  # отдельного пакета в nixpkgs нет. Не добавляем `i3-nagbar` в
  # systemPackages — Nix ругнётся `undefined variable`.
  environment.systemPackages = with pkgs; [
    i3
    i3status
    dmenu
    xterm
    dex
    feh
    dunst
    polybar
    libnotify
  ];
}
