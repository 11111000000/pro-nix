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
      displayManager.lightdm.enable = mkDefault true;
      windowManager.exwm.enable = mkDefault true;
      desktopManager.cinnamon.enable = mkDefault false;
    };

    # Вклад в системные пакеты: только то, что нужно для EXWM и вспомогательных
    # X11-инструментов. Базовый runtime и dev-наборы поставляются другими
    # модулями (например, packages-runtime.nix, system-packages.nix).
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
    ]);
  };
}
