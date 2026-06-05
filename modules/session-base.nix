{ config, pkgs, ... }:

{
  # Базовый вход в графическую среду: дисплейный менеджер, XKB и TTY.
  # Этот файл не знает ничего о конкретном window manager; он фиксирует только
  # те свойства, без которых сессия не стартует предсказуемо.
  services.xserver.enable = true;
  services.xserver.displayManager.lightdm.enable = true;
  services.displayManager.autoLogin.enable = false;

  services.xserver.xkb = {
    layout = "us,ru";
    # Caps работает как Ctrl; одновременное нажатие обоих Shift переключает
    # раскладку (XKB: grp:shifts_toggle); LED CapsLock показывает активную группу.
    # Конфликта с ctrl:nocaps нет: опция grp_led:caps управляет только LED,
    # сами нажатия Caps уже переназначены в Ctrl, что нам и нужно.
    options = "ctrl:nocaps,grp:shifts_toggle,grp_led:caps";
  };
}
