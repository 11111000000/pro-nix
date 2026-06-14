{ pkgs, lib, ... }:

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
  # нет home-manager раскладки .config/sway для каждого юзера, кладём
  # файл через environment.etc — каждый пользователь получает рабочий
  # конфиг "из коробки" (Mod4=Super, waybar, mako, keybindings).
  # Чтобы переопределить — пользователь копирует /etc/sway/config в
  # ~/.config/sway/config и редактирует.
  environment.etc."sway/config".text = ''
    # Sway config — pro-nix default (modules/session-sway.nix).
    # Mod4 = Super (не Alt — не конфликтует с EXWM/Emacs и i3).
    set $mod Mod4
    set $alt Mod1
    set $terminal foot
    set $menu wofi --show drun --insensitive --prompt "search "
    set $browser firefox

    # Output: пусть Sway сам выбрит режим через wlr-randr.
    output * adaptive_sync on

    # Input: базовые настройки, без переназначения Caps (это делает
    # XKB из session-base.nix одинаково для EXWM/i3/Sway).
    input type:keyboard {
      xkb_layout "us,ru"
      xkb_options "ctrl:nocaps,grp:toggle,grp_led:caps"
    }
    input type:touchpad {
      tap enabled
      natural_scroll enabled
    }

    # Автозапуск: status bar + notifications.
    exec dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=sway XDG_SESSION_DESKTOP=sway
    exec waybar
    exec mako

    # Keybindings.
    floating_modifier $mod normal
    bindsym $mod+Return exec $terminal
    bindsym $mod+d exec $menu
    bindsym $mod+Shift+q kill
    bindsym $mod+Shift+e exec swaynag \
      -t warning \
      -m 'What do you want to do?' \
      -B 'Logout' 'swaymsg exit' \
      -B 'Reboot' 'systemctl reboot' \
      -B 'Shutdown' 'systemctl poweroff'
    bindsym $mod+Shift+c reload
    bindsym $mod+Shift+r restart
    bindsym $mod+b splith
    bindsym $mod+v splitv
    bindsym $mod+f fullscreen
    bindsym $mod+Shift+space floating toggle
    bindsym $mod+space focus mode_toggle
    bindsym $mod+Left focus left
    bindsym $mod+Down focus down
    bindsym $mod+Up focus up
    bindsym $mod+Right focus right
    bindsym $mod+Shift+Left move left
    bindsym $mod+Shift+Down move down
    bindsym $mod+Shift+Up move up
    bindsym $mod+Shift+Right move right
    bindsym $mod+1 workspace number 1
    bindsym $mod+2 workspace number 2
    bindsym $mod+3 workspace number 3
    bindsym $mod+4 workspace number 4
    bindsym $mod+5 workspace number 5
    bindsym $mod+6 workspace number 6
    bindsym $mod+7 workspace number 7
    bindsym $mod+8 workspace number 8
    bindsym $mod+9 workspace number 9
    bindsym $mod+Shift+1 move container to workspace number 1
    bindsym $mod+Shift+2 move container to workspace number 2
    bindsym $mod+Shift+3 move container to workspace number 3
    bindsym $mod+Shift+4 move container to workspace number 4
    bindsym $mod+Shift+5 move container to workspace number 5
    bindsym $mod+Shift+6 move container to workspace number 6
    bindsym $mod+Shift+7 move container to workspace number 7
    bindsym $mod+Shift+8 move container to workspace number 8
    bindsym $mod+Shift+9 move container to workspace number 9

    # Layout.
    default_orientation vertical
    bindsym $mod+s layout stacking
    bindsym $mod+w layout tabbed
    bindsym $mod+e layout toggle split

    # Resize (mode).
    mode "resize" {
      bindsym Left resize shrink width 20px
      bindsym Down resize grow height 20px
      bindsym Up resize shrink height 20px
      bindsym Right resize grow width 20px
      bindsym Escape mode "default"
    }
    bindsym $mod+r mode "resize"

    # Screenshot.
    bindsym Print exec grim ~/Pictures/screenshot-$$(date +%Y%m%d-%H%M%S).png
    bindsym $mod+Print exec grim -g "$$(slurp)" ~/Pictures/screenshot-$$(date +%Y%m%d-%H%M%S).png

    # Lock.
    bindsym $mod+Escape exec swaylock -f -c 000000

    # Hide cursor.
    seat seat0 cursor hide_when_typing enabled

    # Title bar: убираем (waybar показывает всё что нужно).
    for_window [class=".*"] title_format ""
    default_border pixel 2
    gaps inner 4
    gaps outer 4
  '';

  # Package list uses plain assignment (not lib.mkDefault) so it is always
  # concatenated with lists from other imported modules.
  environment.systemPackages = with pkgs; [
    sway
    waybar
    mako
    swaybg
    swaylock
    swayidle
    swaynag
    wl-clipboard
    wofi
    foot
    grim
    slurp
  ];
}
