{ config, lib, pkgs, emacsPkg ? pkgs.emacs, ... }:

# Профиль минимального EXWM-окружения.
# Цель:
# - добавить к базовой системе минимальный набор пакетов и X11/EXWM-настроек,
#   достаточный для запуска Emacs+EXWM и работы в графическом режиме;
# - не финализировать мировую политику, а только вносить вклад через mkDefault
#   и композицию списков;
# - позволить переиспользовать этот профиль на разных хостах (cf19, vm, другие
#   лёгкие ноутбуки) без жёсткой привязки к железу.
#
# Single source of truth:
# До профилирования EXWM-сессия жила в modules/session-exwm.nix. После
# `windowManager.session = mkForce []` (вычистки nixpkgs-EXWM-сессии) единственная
# оставшаяся xsession-запись — pro-exwm-xsession с Exec=$HOME/.config/pro/exwm-session.
# Если профиль не генерирует её сам, greeter показывает пустое меню и EXWM
# не запускается. Здесь мы собираем всю EXWM-сессию в одном модуле, чтобы
# `pro.profiles.exwmMinimal.enable = true` действительно был достаточным
# условием рабочей EXWM-сессии.

let
  inherit (lib) mkDefault mkIf;

  cfg = config.pro.profiles.exwmMinimal;

  # Canonical EXWM xsession entry. Раньше генерировался в
  # modules/session-exwm.nix, теперь живёт здесь.  LightDM/SDDM читают
  # /run/current-system/share/xsessions/*.desktop и показывают их в greeter.
  # Exec запускает home-manager-managed скрипт ~/.config/pro/exwm-session,
  # который генерируется в emacs/exwm.nix (гейт: pro.emacs.gui.enable).
  exwmXsession = pkgs.runCommand "pro-exwm-xsession"
    { passthru.providedSessions = [ "exwm" ]; }
    ''
      mkdir -p $out/share/xsessions
      # EXWM — X11-only compositor. Симлинк в wayland-sessions НЕ кладём:
      # Sway/SDDM иначе предлагают "EXWM" в Wayland-меню, а EXWM через
      # xwayland из wayland-greeter стартует и падает в самом неожиданном
      # месте (см. commit 6fdc5ac).
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
    '';

in {
  # Объявляем только подопции для профиля exwmMinimal. Само пространство
  # pro.profiles определяется в modules/pro-profiles.nix.
  options.pro.profiles.exwmMinimal.enable =
    lib.mkEnableOption "минимальный EXWM-профиль без тяжёлого desktop branch";

  config = mkIf cfg.enable {
    # ВАЖНО: `pro.emacs.gui.enable` — это home-manager-опция (объявлена
    # в emacs/core.nix, импортируется через emacs/home-manager.nix в
    # modules/pro-users-nixos.nix). NixOS-модуль не может её напрямую
    # установить — `pro.emacs` не существует на уровне nixosSystem.
    # Мост NixOS→HM живёт в modules/pro-users.nix: оттуда для каждого
    # HM-пользователя устанавливается `pro.emacs.gui.enable = 
    # config.pro.profiles.exwmMinimal.enable or false;`. Без этого
    # `~/.config/pro/exwm-session` (emacs/exwm.nix, гейт cfg.gui.enable)
    # не генерируется, и greeter запускает bash на несуществующий путь.

    # Минимальный набор X11/EXWM-служб. Остальная графическая политика
    # (менеджер входа, дополнительные desktopManager'ы) настраивается в других
    # модулях-профилях.
    services.xserver = {
      enable = mkDefault true;
      windowManager.exwm.enable = mkDefault true;
      # nixpkgs модуль (nixos/modules/services/x11/window-managers/exwm.nix)
      # при `windowManager.exwm.enable = true` добавляет свою запись в
      # `windowManager.session` с name = "exwm" и Exec вида
      # `${emacs}/bin/emacs -l ${loadScript}` (без ~/.xprofile, без
      # systemd-run, без ssh-agent). Эта запись попадает в
      # /etc/X11/sessions/ и LightDM/Sway показывает её в меню рядом с
      # нашей `pro-exwm-xsession`. В NixOS 25.11 опции `useDefaultSessionFile`
      # нет — вычищаем её через `mkForce`. `[]` означает "убрать
      # nixpkgs-сессию, оставить только pro-exwm-xsession из sessionPackages".
      windowManager.session = lib.mkForce [];
      desktopManager.cinnamon.enable = mkDefault false;
    };

    services.xserver.displayManager.lightdm.enable = mkDefault true;
    services.displayManager.gdm.enable = mkDefault false;

    # LightDM выполняет sessionCommands ДО exec'а выбранной xsession —
    # это единственное место, где можно настроить PATH и смерджить
    # Xresources до старта Emacs. Раньше жил в modules/session-exwm.nix.
    services.xserver.displayManager.sessionCommands = ''
      export PATH="/run/wrappers/bin:$HOME/.local/bin:/run/current-system/sw/bin:$PATH"
      export EMACS_STARTUP_LOG_DIR="$HOME/.cache/emacs-startup"
      export EMACS_STARTUP_LOG_FILE="$EMACS_STARTUP_LOG_DIR/gdm-exwm.log"
      mkdir -p "$EMACS_STARTUP_LOG_DIR"
      printf '%s\n' "[sessionCommands $(date '+%F %T%z')] path=$PATH log_file=$EMACS_STARTUP_LOG_FILE"
      # Merge Xresources from the system location first, then the user override
      # if present.  The system file is deployed by configuration.nix via
      # environment.etc."X11/Xresources", which is the only guaranteed location
      # when home-manager is not active for this user.
      [ -r /etc/X11/Xresources ] && xrdb -merge /etc/X11/Xresources || true
      [ -f "$HOME/.Xresources" ] && xrdb -merge "$HOME/.Xresources" || true
    '';

    # Регистрируем xsession-файл pro-exwm-xsession. Раньше — session-exwm.nix.
    services.displayManager.sessionPackages = [ exwmXsession ];

    # Окружение EXWM-сессии: курсор, темы, локаль, IME-переменные.
    # lib.mkDefault — чтобы pro-desktop.nix (где GTK_KEY_THEME/QT_* уже
    # заданы глобально через environment.variables) мог переопределить.
    environment.variables = {
      GTK_KEY_THEME = mkDefault "Emacs";
      QT_QPA_PLATFORMTHEME = mkDefault "qt5ct";
      XCURSOR_THEME = "Adwaita";
      XCURSOR_SIZE = "24";
      LANG = "ru_RU.UTF-8";
      LC_CTYPE = "ru_RU.UTF-8";
    };

    # xdg-desktop-portal: gtk-бэкенд для скриншотов/выбора файлов из X11-приложений.
    xdg.portal = {
      enable = true;
      extraPortals = mkDefault [ pkgs.xdg-desktop-portal-gtk ];
    };

    # Package list uses plain assignment (not lib.mkDefault) so it is always
    # concatenated with lists from other imported modules (per AGENTS §2).
    # Объединение двух прежних списков: profile-exwm-minimal.nix + session-exwm.nix.
    # gawk нужен для powerManagement.* скриптов на cf19; xbindkeys —
    # для xbindkeys grab из ~/.xprofile (см. emacs/exwm.nix); xvfb-run —
    # для headless-тестов EXWM и pro-emacs-rescue.
    environment.systemPackages = with pkgs; [
      gawk
      xorg.xset
      xorg.xhost
      xorg.setxkbmap
      xorg.xsetroot
      wmname
      xbindkeys
      xdotool
      xclip
      xauth
      xvfb-run
    ];
  };
}
