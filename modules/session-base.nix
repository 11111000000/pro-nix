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
    # Caps работает как Ctrl; Right Alt переключает раскладку; CapsLock LED показывает активную группу.
    options = "ctrl:nocaps,grp:ralt_toggle,grp_led:caps";
  };
}
