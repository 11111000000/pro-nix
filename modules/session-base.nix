{ config, pkgs, ... }:

{
  # Базовый вход в графическую среду: дисплейный менеджер, XKB и TTY.
  # Этот файл не знает ничего о конкретном window manager; он фиксирует только
  # те свойства, без которых сессия не стартует предсказуемо.
  services.xserver.enable = true;
  services.displayManager.gdm.enable = true;
  services.displayManager.autoLogin.enable = false;

  services.xserver.xkb = {
    layout = "us,ru";
    options = "grp:ralt_toggle,caps:ctrl_modifier,grp_led:caps";
  };
}
