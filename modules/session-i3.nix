{ pkgs, lib, ... }:

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
  # $XDG_CONFIG_HOME/i3/config, потом /etc/i3/config. Поскольку у нас
  # нет home-manager раскладки .config/i3 для каждого юзера, кладём
  # файл через environment.etc — каждый пользователь получает рабочий
  # конфиг "из коробки" (Mod4=Super, polybar, dmenu, keybindings,
  # совместимые с Sway). Чтобы переопределить — пользователь копирует
  # /etc/i3/config в ~/.config/i3/config и редактирует.
  environment.etc."i3/config".text = ''
    # i3 config — pro-nix default (modules/session-i3.nix).
    # Mod4 = Super (не Alt — не конфликтует с EXWM/Emacs).
    set $mod Mod4
    set $alt Mod1
    set $terminal xterm
    set $menu dmenu_run
    set $browser firefox

    # Font.
    font pango:monospace 9

    # Keybindings.
    floating_modifier $mod
    bindsym $mod+Return exec $terminal
    bindsym $mod+d exec $menu
    bindsym $mod+Shift+q kill
    bindsym $mod+Shift+e exec i3-nagbar -t warning -m 'Logout?' -B 'Yes' 'i3-msg exit'
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
      bindsym Left resize shrink width 20px or 20ppt
      bindsym Down resize grow height 20px or 20ppt
      bindsym Up resize shrink height 20px or 20ppt
      bindsym Right resize grow width 20px or 20ppt
      bindsym Escape mode "default"
    }
    bindsym $mod+r mode "resize"

    # Status bar: polybar вместо i3bar (более гибкий и не требует
    # отдельного config). С Polybar запускается как shell exec, конфиг
    # /etc/polybar/config.ini раскладывается через environment.etc
    # отдельным модулем (если используется).
    bar {
      status_command polybar --reload example
      position top
      height 24
    }

    # Title bar: убираем.
    for_window [class=".*"] title_format ""

    # Gaps: визуально отделяем окна (как в Sway-конфиге).
    gaps inner 4
    gaps outer 4

    # Autostart.
    exec --no-startup-id dex --autostart --environment i3
    exec --no-startup-id dunst
  '';

  # Дефолтный polybar config. Используется status bar, который
  # прописан в i3.config выше. Минимальный, чтобы не падал.
  environment.etc."polybar/config.ini".text = ''
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

  # Package list uses plain assignment (not lib.mkDefault) so it is always
  # concatenated with lists from other imported modules.
  environment.systemPackages = with pkgs; [
    i3
    i3status
    i3-nagbar
    dmenu
    xterm
    dex
    feh
    dunst
    polybar
    libnotify
  ];
}
