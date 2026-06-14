{ pkgs, lib, ... }:

let
  # Single source of truth: conf/sway-config.in читается и здесь
  # (system-wide /etc/sway/config) и в emacs/exwm.nix (per-user
  # ~/.config/sway/config). Текст один, чтобы биндинги не расходились
  # между системным fallback и пользовательским override.
  swayConfig = builtins.readFile ../conf/sway-config.in;
in

{
  # Sway — Wayland-tile WM. Запускаем под `dbus-run-session`, чтобы Sway
  # получил собственный dbus session bus (нужен для mako/waybar,
  # xdg-desktop-portal и т.п.). Без dbus Sway стартует, но через ~2 секунды
  # wlroots падает на попытке поднять wl_compositor — пользователь видит
  # "вылетает" (return code 1, lightdm откатывает на login).
  #
  # WLR_NO_HARDWARE_CURSORS=1 — workaround для Intel GPU mode-setting
  # (на некоторых сериях hw-курсоры ломают композитор при выходе
  # из sleep / на multi-monitor setup).
  services.displayManager.sessionPackages = [
    (pkgs.runCommand "pro-sway-session" { passthru.providedSessions = [ "sway" ]; } ''
      mkdir -p $out/share/wayland-sessions
      cat > $out/share/wayland-sessions/sway.desktop <<'EOF'
[Desktop Entry]
Name=Sway
Comment=Wayland compositor and window manager
Exec=/usr/bin/env bash -lc "exec env WLR_NO_HARDWARE_CURSORS=1 XDG_CURRENT_DESKTOP=sway XDG_SESSION_DESKTOP=sway dbus-run-session -- sway"
Type=Application
DesktopNames=Sway
EOF
      chmod -R a+rX $out
    '')
  ];

  # System-wide fallback ~/.config/sway/config. Sway ищет сначала
  # $XDG_CONFIG_HOME/sway/config, потом /etc/sway/config. Поскольку у нас
  # есть home-manager-managed копия в ~/.config/sway/config (см. emacs/exwm.nix),
  # per-user override выигрывает; /etc/sway/config остаётся для greeter
  # и пользователей без home-manager. Конфиг в EXWM-стиле (Mod4+h/j/k/l
  # для focus/move — как в EXWM windmove, Mod4+Space для app launcher,
  # чтобы не конфликтовать с EXWM s-d=treemacs). Полная документация
  # по биндингам — в conf/sway-config.in.
  environment.etc."sway/config".text = swayConfig;

  # Package list uses plain assignment (not lib.mkDefault) so it is always
  # concatenated with lists from other imported modules.
  # NB: swaynag — бинарь из пакета `sway` (${sway}/bin/swaynag), не отдельный
  # пакет в этом nixpkgs. Не добавляем swaynag в systemPackages — Nix ругнётся.
  environment.systemPackages = with pkgs; [
    sway
    waybar
    mako
    swaybg
    swaylock
    swayidle
    wl-clipboard
    wofi
    foot
    grim
    slurp
  ];
}
