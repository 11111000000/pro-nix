{ pkgs, lib, config, ... }:

# Change Gate
# Intent: TTY-раскладка наследуется из XKB (services.xserver.xkb), переключение
# на русскую и обратно — Right Alt (XKB option grp:toggle). Шрифт — Unicode-PSF
# с кириллицей (LatArCyrHeb-16), чтобы UTF-8 локаль ru_RU.UTF-8 рисовалась
# правильно. Никаких ручных loadkeys-патчей.
# Pressure: Debt
# Surface impact: NixOS Base Configuration — поведение TTY для раскладок
#                совпадает с X11/XKB: layout = "us,ru", options = "grp:toggle".
# Proof: systemd-vconsole-setup стартует без ошибок; на виртуальной консоли
#        Right Alt переключает группу, кириллица отображается.
# Migration: none.

let
  # Unicode PSF font с кириллицей (Latin/Arabic/Cyrillic/Hebrew, 8x16).
  # Старый Cyr_a8x14.psfu.gz основан на cp866 (см. README.Cyrillic в pkgs.kbd)
  # и не работает с UTF-8 локалью: позиции 0200-0257 содержат глифы по
  # кодам cp866, а не Unicode, поэтому UTF-8 байты Cyrillic не находят
  # глиф. LatArCyrHeb-* использует Unicode-таблицу и рисует UTF-8 напрямую.
  ttyFont = "${pkgs.kbd}/share/consolefonts/LatArCyrHeb-16.psfu.gz";
in
{
  console = {
    # Используем XKB-конфигурацию, чтобы консольная раскладка совпадала с X11.
    useXkbConfig = lib.mkDefault true;
    earlySetup = lib.mkDefault true;
    font = lib.mkDefault ttyFont;
    # Не генерируем кастомные loadkeys-таблицы — XKB обработает группу
    # раскладок и переключение по Right Alt согласно services.xserver.xkb.
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
