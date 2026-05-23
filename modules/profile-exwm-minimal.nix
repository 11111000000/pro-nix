{ config, lib, pkgs, ... }:

# Профиль минимального EXWM-окружения.
# Цель:
# - добавить к базовой системе минимальный набор пакетов и X11/EXWM-настроек,
#   достаточный для запуска Emacs+EXWM и работы в графическом режиме;
# - не финализировать мировую политику, а только вносить вклад через mkDefault
#   и композицию списков;
# - позволить переиспользовать этот профиль на разных хостах (cf19, vm, другие
#   лёгкие ноутбуки) без жёсткой привязки к железу.

let
  inherit (lib) mkDefault mkIf;

  cfg = config.pro.profiles.exwmMinimal;

in {
  # Объявляем только подопции для профиля exwmMinimal. Само пространство
  # pro.profiles определяется в modules/pro-profiles.nix.
  options.pro.profiles.exwmMinimal.enable =
    lib.mkEnableOption "минимальный EXWM-профиль без тяжёлого desktop branch";

  config = mkIf cfg.enable {
    # Минимальный набор X11/EXWM-служб. Остальная графическая политика
    # (менеджер входа, дополнительные desktopManager'ы) настраивается в других
    # модулях-профилях.
    services.xserver = {
      enable = mkDefault true;
      displayManager.gdm.enable = mkDefault true;
      displayManager.lightdm.enable = mkDefault false;
      windowManager.exwm.enable = mkDefault true;
      desktopManager.cinnamon.enable = mkDefault false;
    };

    # EXWM desktop entry нужен дисплейному менеджеру независимо от того,
    # подключён ли полный desktop-слой. Файл создаётся в xsession-пакете,
    # который GDM сканирует через `share/xsessions`.
    environment.systemPackages = mkDefault (with pkgs; [
      xorg.xset
      xorg.xhost
      xorg.setxkbmap
      xorg.xsetroot
      wmname
      xbindkeys
      xdotool
      xclip
      xauth
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
  };
}
