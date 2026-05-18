# Название: modules/pro-desktop.nix — Настройки рабочего стека и шрифтов
# Summary (EN): Desktop environment defaults, display manager, fonts and audio
# Цель:
#   Сформировать устойчивый и предсказуемый графический профиль: включить
#   дисплейный менеджер, дефолты сессии, набор шрифтов и современный аудиостек.
# Контракт:
#   Опции: services.xserver.enable, services.displayManager.gdm.enable,
#           fonts.packages — список шрифтов; environment.etc.* — конфигурация GTK/Qt.
#   Побочные эффекты: добавляет xsession файл для EXWM, разворачивает шрифты в
#   профиль, настраивает pipewire/pulseaudio сопутствующие службы.
# Предпосылки:
#   Требуются пакеты terminus_font, noto-fonts; некоторые конфигурации зависят
#   от версии NixOS (опции могут отсутствовать в старых версиях).
# Как проверить (Proof):
#   Откройте GDM/EXWM с этим профилем или проверьте наличие $out/share/xsessions/exwm.desktop
# Last reviewed: 2026-05-03
{ config, pkgs, lib, ... }:

{
  # Этот файл остаётся фасадом старого desktop-слоя, но сам он больше не
  # смешивает все подсистемы в один узел. Каждая подсистема получает свою
  # ответственную секцию и может переехать в отдельный модуль без изменения
  # итогового поведения хоста.

  # Базовый графический контур: дисплейный менеджер, X11 и вход в сессию.
  services.xserver.enable = true;
  services.displayManager.gdm.enable = true;
  services.xserver.desktopManager.cinnamon.enable = true;
  services.displayManager.autoLogin.enable = false;

  # Сеанс начинается здесь: PATH, лог-файлы и первичные Xresources должны быть
  # доступны до запуска EXWM и пользовательских wrapper-ов.
  services.xserver.displayManager.sessionCommands = ''
    export PATH="/run/wrappers/bin:$HOME/.local/bin:/run/current-system/sw/bin:$PATH"
    export EMACS_STARTUP_LOG_DIR="$HOME/.cache/emacs-startup"
    export EMACS_STARTUP_LOG_FILE="$EMACS_STARTUP_LOG_DIR/gdm-exwm.log"
    mkdir -p "$EMACS_STARTUP_LOG_DIR"
    printf '%s\n' "[sessionCommands $(date '+%F %T%z')] path=$PATH log_file=$EMACS_STARTUP_LOG_FILE"
    [ -f "$HOME/.Xresources" ] && xrdb -merge "$HOME/.Xresources" || true
  '';

  # Консоль должна повторять раскладку сессии: одна и та же клавиатурная
  # логика на TTY и в графике уменьшает количество скрытых режимов.
  console.useXkbConfig = true;
  console.earlySetup = true;
  console.font = "${pkgs.terminus_font}/share/consolefonts/ter-v16n.psf.gz";
  services.xserver.xkb = {
    layout = "us,ru";
    options = "grp:ralt_toggle,caps:ctrl_modifier,grp_led:caps";
  };

  # Дополнительные getty и спокойный kbdrate делают переход между X и TTY
  # предсказуемым на ноутбуке и в recovery-режиме.
  systemd.services."getty@tty2".enable = true;
  systemd.services."getty@tty3".enable = true;
  systemd.services.kbdrate = {
    description = "Задание интервалов повторения на виртуальной консоли";
    wantedBy = [ "multi-user.target" ];
    after = [ "getty@tty1.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.kbd}/bin/kbdrate -d 900 -r 7";
    };
  };

  # Аудио-слой отделён от EXWM: он обслуживает desktop runtime, но не должен
  # влиять на выбор оконного менеджера.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  # Порталы дают графическим приложениям доступ к системным возможностям.
  xdg.portal = {
    enable = true;
    extraPortals = lib.mkDefault [ pkgs.xdg-desktop-portal-gtk ];
  };

  # Шрифты, GTK/Qt и Xresources образуют визуальную политику сессии. Этот
  # набор должен жить отдельно от логики запуска, чтобы его можно было
  # переиспользовать и для EXWM, и для Cinnamon без копирования.
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
  fonts.fontconfig.defaultFonts = {
    sansSerif = [ "Aporetic Sans" "DejaVu Sans" ];
    serif = [ "Aporetic Sans Serif" ];
    monospace = [ "Aporetic Sans Mono" "Terminus" ];
  };
  environment.etc."fonts.conf".source = ../conf/fonts.conf;
  environment.etc."gtk-3.0/settings.ini".source = ../conf/gtk-3.0-settings.ini;
  environment.etc."gtk-4.0/settings.ini".source = ../conf/gtk-4.0-settings.ini;
  environment.etc."gtk-2.0/gtkrc".source = ../conf/gtkrc-2.0;
  environment.etc."xdg/qt5ct/qt5ct.conf".source = ../conf/qt5ct.conf;
  environment.etc."xdg/qt6ct/qt6ct.conf".source = ../conf/qt6ct.conf;
  environment.etc."xdg/kdeglobals".source = ../conf/kdeglobals;
  environment.etc."X11/Xresources".text = builtins.readFile ../conf/Xresources;
  environment.etc."xdg/dunst/dunstrc".source = ../conf/dunstrc;

  # Базовые переменные среды фиксируют язык и тему так, чтобы EXWM, GTK и Qt
  # не спорили друг с другом при старте.
  environment.variables = {
    LANG = "ru_RU.UTF-8";
    LC_CTYPE = "ru_RU.UTF-8";
    GTK_KEY_THEME = lib.mkDefault "Emacs";
    QT_QPA_PLATFORMTHEME = lib.mkDefault "qt5ct";
    XCURSOR_THEME = "Adwaita";
    XCURSOR_SIZE = "24";
  };

  # Система пакетов здесь тоже пока фасад: EXWM entrypoint, qt5ct/qt6ct и gawk
  # остаются рядом с графическим слоем, потому что они обслуживают запуск
  # desktop-сессии, а не базовый runtime.
  environment.systemPackages = lib.mkDefault (with pkgs; [
    gawk
    qt5ct
    qt6ct
    (runCommand "pro-exwm-xsession" {} ''
      mkdir -p $out/share/xsessions
      cat > $out/share/xsessions/exwm.desktop <<'EOF'
[Desktop Entry]
Name=EXWM
Comment=Emacs Window Manager
Exec=/usr/bin/env bash -lc "$HOME/.config/pro/exwm-session"
Type=Application
DesktopNames=EXWM
X-GNOME-WmName=EXWM
X-GNOME-Bugzilla-Bugzilla=Emacs
X-GNOME-Bugzilla-Product=Emacs
X-GNOME-Bugzilla-Component=window-manager
EOF
      chmod -R a+rX $out
    '')
  ]);

  # Firefox здесь оставлен только как совместимый переходный слой. После
  # завершения разбиения desktop/app policy он переедет в отдельный пакетный
  # набор, чтобы session-модуль описывал только сам вход в графическую среду.
  programs.firefox.enable = true;
  programs.firefox.package = pkgs.firefox;
}
