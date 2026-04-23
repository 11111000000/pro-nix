# Раздел: рабочая среда и графический стек — учебное изложение
#
# Суть:
# Этот модуль собирает настройки графического стека (X11/Wayland, менеджер
# отображения, шрифты, звуковая подсистема) и предъявляет их как набор
# взаимосвязанных свойств. Комментарии объясняют назначение опций, их влияние
# на пользовательский опыт и на взаимодействие с другими модулями.
{ config, pkgs, lib, ... }:

{
  services.xserver.enable = true;
  services.displayManager.gdm.enable = true;
  services.xserver.desktopManager.cinnamon.enable = true;
  # Сеансовые команды на уровне дисплей-менеджера задают окружение до запуска графической среды.
  services.xserver.displayManager.sessionCommands = ''
    export PATH="/run/wrappers/bin:$HOME/.local/bin:/run/current-system/sw/bin:$PATH"
    export EMACS_STARTUP_LOG_DIR="$HOME/.cache/emacs-startup"
    export EMACS_STARTUP_LOG_FILE="$EMACS_STARTUP_LOG_DIR/gdm-exwm.log"
    mkdir -p "$EMACS_STARTUP_LOG_DIR"
    printf '%s\n' "[sessionCommands $(date '+%F %T%z')] path=$PATH log_file=$EMACS_STARTUP_LOG_FILE"
    [ -f "$HOME/.Xresources" ] && xrdb -merge "$HOME/.Xresources" || true
  '';
  services.displayManager.autoLogin.enable = false;

  # Консоль берёт ту же раскладку, что и графика: пользователь не должен учить две разные клавиатуры.
  console.useXkbConfig = true;
  console.earlySetup = true;
  console.font = "${pkgs.terminus_font}/share/consolefonts/ter-v16n.psf.gz";

  # Make VT feel calmer: hide blinking cursor by default.
  # The 'vt' option path isn't defined in all NixOS versions/modules; avoid
  # referencing a non-existent option to keep module evaluation robust.

  # Provide extra getty instances so several textual consoles are available
  # from X (Ctrl+Alt+F2 / Ctrl+Alt+F3). Individual hosts may override.
  systemd.services."getty@tty2".enable = true;
  systemd.services."getty@tty3".enable = true;

  # Optional: if a host needs to force native resolution on VT, set
  # boot.kernelParams = [ "video=1920x1080" ]; in that host's configuration.

  services.xserver.xkb = {
    layout = "us,ru";
    options = "grp:ralt_toggle,caps:ctrl_modifier,grp_led:caps";
  };

  # `kbdrate` устанавливает скорость повторения клавиш на виртуальной консоли.
  systemd.services.kbdrate = {
    description = "Задание интервалов повторения на виртуальной консоли";
    wantedBy = [ "multi-user.target" ];
    after = [ "getty@tty1.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.kbd}/bin/kbdrate -d 900 -r 7";
    };
  };

  # PipeWire здесь заменяет старый аудиослой и собирает звук в один современный контур.
  # The pulseaudio option was moved to services.pulseaudio in newer NixOS
  # versions. Keep the same intent but use the new option name.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  # Порталы XDG связывают графические приложения с системными возможностями.
  xdg.portal = {
    enable = true;
    extraPortals = lib.mkForce [ pkgs.xdg-desktop-portal-gtk ];
  };

  # Шрифты размещены рядом с графическим слоем.
  fonts.packages = with pkgs; [
    terminus_font
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    (stdenv.mkDerivation rec {
      name = "aporetic-fonts";
      src = ../fonts;
      installPhase = ''
        mkdir -p $out/share/fonts/truetype
        cp $src/*.ttf $out/share/fonts/truetype/
      '';
    })
    liberation_ttf
    dejavu_fonts
    cantarell-fonts
  ];

  # Шрифтовая политика: выбор системных семейств для fontconfig.
  # Примечание: в современных версиях NixOS используются имена семейств
  # 'sansSerif', 'serif', 'monospace' — здесь задаём удобный набор по умолчанию.
  fonts.fontconfig.defaultFonts = {
    sansSerif = [ "Aporetic Sans" "DejaVu Sans" ];
    monospace = [ "Aporetic Sans Mono" "Terminus" ];
  };

  # Deploy toolkit font config snippets for GTK/Qt/X11 so GNOME/Cinnamon and
  # other desktop environments pick up Aporetic as the default font.
  environment.etc."fonts.conf".source = ../conf/fonts.conf;
  environment.etc."gtk-3.0/settings.ini".source = ../conf/gtk-3.0-settings.ini;
  environment.etc."gtk-4.0/settings.ini".source = ../conf/gtk-4.0-settings.ini;
  environment.etc."gtk-2.0/gtkrc".source = ../conf/gtkrc-2.0;
  environment.etc."xdg/qt5ct/qt5ct.conf".source = ../conf/qt5ct.conf;
  environment.etc."xdg/qt6ct/qt6ct.conf".source = ../conf/qt6ct.conf;
  environment.etc."xdg/kdeglobals".source = ../conf/kdeglobals;
  environment.etc."X11/Xresources".source = ../conf/Xresources;
  environment.etc."xdg/dunst/dunstrc".source = ../conf/dunstrc;

  # Глобальные переменные задают системные настройки локали и темы.
  environment.variables = {
    LANG = "ru_RU.UTF-8";
    LC_CTYPE = "ru_RU.UTF-8";
    GTK_KEY_THEME = "Emacs";
    QT_QPA_PLATFORMTHEME = lib.mkForce "qt5ct";
    XCURSOR_THEME = "Adwaita";
    XCURSOR_SIZE = "24";
  };

  # Ensure awk is available during activation (some activation scripts use awk).
  environment.systemPackages = lib.mkForce ((config.environment.systemPackages or []) ++ (with pkgs; [ gawk
    # Install a system-wide xsessions entry so GDM shows EXWM for all users.
    (runCommand "pro-exwm-xsession" {} ''
      mkdir -p $out/share/xsessions
      cat > $out/share/xsessions/exwm.desktop <<'EOF'
[Desktop Entry]
Name=EXWM
Comment=Emacs Window Manager
Exec=/bin/bash -lc '$HOME/.config/pro/exwm-session'
Type=Application
DesktopNames=EXWM
X-GNOME-WmName=EXWM
X-GNOME-Bugzilla-Bugzilla=Emacs
X-GNOME-Bugzilla-Product=Emacs
X-GNOME-Bugzilla-Component=window-manager
EOF
      chmod -R a+rX $out
    '')
  ]));

  # Firefox включён как системный браузер.
  programs.firefox.enable = true;
  programs.firefox.package = pkgs.firefox;
}
