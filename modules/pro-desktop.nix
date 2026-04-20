{ pkgs, lib, ... }:

{
  services.xserver.enable = true;
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.cinnamon.enable = true;
  # Сеансовые команды на уровне дисплей-менеджера собирают те детали, которые должны появиться до запуска графической среды, но не жить в системе как закон.
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

  services.xserver.xkb = {
    layout = "us,ru";
    options = "grp:ralt_toggle,caps:ctrl_modifier,grp_led:caps";
  };

  # `kbdrate` удерживает TTY в человеческом темпе, чтобы консоль не становилась источником раздражения.
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
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  # Порталы XDG нужны как мост между графическими приложениями и системными возможностями.
  xdg.portal = {
    enable = true;
    extraPortals = lib.mkForce [ pkgs.xdg-desktop-portal-gtk ];
  };

  # Шрифты формируют визуальный ритм рабочего места, поэтому они лежат рядом с графическим слоем.
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

  # Моноширинный набор отражает выбор консольной и редакторной дисциплины.
  fonts.fontconfig.defaultFonts.monospace = [ "Terminus" "Aporetic Sans Mono" ];

  # Глобальные переменные фиксируют общий язык интерфейса и внешнего вида, чтобы разные программы не спорили о том, как выглядит рабочий день.
  environment.variables = {
    LANG = "ru_RU.UTF-8";
    LC_CTYPE = "ru_RU.UTF-8";
    GTK_KEY_THEME = "Emacs";
    QT_QPA_PLATFORMTHEME = lib.mkForce "qt5ct";
    XCURSOR_THEME = "Adwaita";
    XCURSOR_SIZE = "24";
  };

  # Firefox оставлен как базовый браузер рабочего окружения.
  programs.firefox.enable = true;
  programs.firefox.package = pkgs.firefox;
}
