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
      windowManager.exwm.enable = mkDefault true;
      # nixpkgs модуль (nixos/modules/services/x11/window-managers/exwm.nix)
      # при `windowManager.exwm.enable = true` добавляет свою запись в
      # `windowManager.session` с name = "exwm" и Exec вида
      # `${emacs}/bin/emacs -l ${loadScript}` (без ~/.xprofile, без
      # systemd-run, без ssh-agent). Эта запись попадает в /etc/X11/sessions/
      # и LightDM/Sway показывает её в меню рядом с нашей
      # `pro-exwm-xsession`. В NixOS 25.11 опции `useDefaultSessionFile` нет
      # — вычищаем её через `mkForce` (на хостах pro-nix EXWM — единственный
      # включённый windowManager.*, см. grep, так что `[]` означает "убрать
      # nixpkgs-сессию, оставить только pro-exwm-xsession из sessionPackages").
      # Канонический launcher живёт в modules/session-exwm.nix:
      # ~/.config/pro/exwm-session (ssh-agent + xbindkeys rescue +
      # systemd-run + XDG_CURRENT_DESKTOP).
      windowManager.session = lib.mkForce [];
      desktopManager.cinnamon.enable = mkDefault false;
    };

    services.xserver.displayManager.lightdm.enable = mkDefault true;
    services.displayManager.gdm.enable = mkDefault false;


    # Package list uses plain assignment (not mkDefault) so it is always
    # concatenated with lists from other imported modules.
    environment.systemPackages = with pkgs; [
      xorg.xset
      xorg.xhost
      xorg.setxkbmap
      xorg.xsetroot
      wmname
      xdotool
      xclip
      xauth
    ];
  };
}
