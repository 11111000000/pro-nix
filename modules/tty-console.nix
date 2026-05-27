{ pkgs, lib, config, ... }:

# Change Gate
# Intent: Упростить конфигурацию TTY-раскладки: использовать XKB для виртуальной
# консоли и переключать en/ru через Right Alt (RAlt). Убрать генерирование и
# патчи keymap-скриптов — это излишне.
# Pressure: Debt
# Surface impact: NixOS Base Configuration — поведение TTY для раскладок будет
#                совпадать с X11/XKB: layout = "us,ru", options = "grp:ralt_toggle".
# Proof: Проверка systemd-vconsole-setup и простая ручная проверка переключения
#        раскладки на виртуальной консоли (RAlt).
# Migration: none.

let
  ttyFont = "${pkgs.kbd}/share/consolefonts/Cyr_a8x14.psfu.gz";
in
{
  console = {
    # Используем XKB-конфигурацию, чтобы консольная раскладка совпадала с X11.
    useXkbConfig = lib.mkDefault true;
    earlySetup = lib.mkDefault true;
    font = lib.mkDefault ttyFont;
    # Не генерируем кастомные loadkeys-таблицы —XKB обработает группу раскладок
    # и переключение по Right Alt согласно services.xserver.xkb.
  };

  services.gpm = {
    enable = lib.mkDefault true;
  };

  systemd.services."getty@tty2".enable = lib.mkDefault true;
  systemd.services."getty@tty3".enable = lib.mkDefault true;

  systemd.services.kbdrate = {
    description = "Задание интервалов повторения на виртуальной консоли";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-vconsole-setup.service" ];
    unitConfig.ConditionPathExists = "/sys/module/i8042";
    serviceConfig = {
      Type = "oneshot";
      # kbdrate работает только при наличии i8042. На USB-only/VM хостах
      # сервис пропускается через ConditionPathExists и не влияет на switch.
      ExecStart = "${pkgs.kbd}/bin/kbdrate -d 250 -r 30";
      SuccessExitStatus = [ 0 1 ];
    };
  };
}
