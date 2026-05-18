{ config, pkgs, ... }:

{
  # Базовый вход в графическую среду: дисплейный менеджер, XKB и TTY.
  # Этот файл не знает ничего о конкретном window manager; он фиксирует только
  # те свойства, без которых сессия не стартует предсказуемо.
  services.xserver.enable = true;
  services.displayManager.gdm.enable = true;
  services.displayManager.autoLogin.enable = false;

  console.useXkbConfig = true;
  console.earlySetup = true;
  console.font = "${pkgs.terminus_font}/share/consolefonts/ter-v16n.psf.gz";

  services.xserver.xkb = {
    layout = "us,ru";
    options = "grp:ralt_toggle,caps:ctrl_modifier,grp_led:caps";
  };

  # Два дополнительных getty делают выход из X в TTY неисчезающим: пользователь
  # всегда может попасть в текстовую консоль, даже если графическая сессия упала.
  systemd.services."getty@tty2".enable = true;
  systemd.services."getty@tty3".enable = true;

  # `kbdrate` здесь не ради красоты, а ради повторяемого tactile baseline на
  # ноутбуках и старом железе.
  systemd.services.kbdrate = {
    description = "Задание интервалов повторения на виртуальной консоли";
    wantedBy = [ "multi-user.target" ];
    after = [ "getty@tty1.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.kbd}/bin/kbdrate -d 900 -r 7";
    };
  };
}
