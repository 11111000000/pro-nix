{ pkgs, lib, config, ... }:

/*
Change Gate
Intent: Сделать TTY-шрифт и keymap виртуальной консоли безопасными для активации.
Pressure: Ops
Surface impact: NixOS Base Configuration [FROZEN] — виртуальные консоли получают
                общий UTF-8 шрифт и совместимый keymap без зависимости от desktop-модулей.
Proof: `systemd-analyze verify /etc/systemd/system/systemd-vconsole-setup.service`
       и проверка `nix eval --json .#nixosConfigurations.<host>.config.console.keyMap`.
Migration: none.
*/

let
  ttyFont = "${pkgs.kbd}/share/consolefonts/Cyr_a8x14.psfu.gz";

  # Генерируем keymap из XKB через ckbcomp, чтобы избежать unknown keysym
  # в stock-раскладках kbd (U+0439 → cyrillic_small_letter_short_i неизвестен
  # в kbd-2.9.0). После генерации фиксим Right Alt (keycode 100) так, чтобы
  # он переключал раскладку в консоли (AltGr_Lock вместо просто Alt).
  ruConsoleKeymap = pkgs.runCommand "ru-console-keymap" {
    nativeBuildInputs = [ pkgs.buildPackages.ckbcomp ];
    preferLocalBuild = true;
  } ''
    ckbcomp \
      -model pc105 -layout us,ru \
      -option grp:ralt_toggle,grp_led:caps > "$out"
    # ckbcomp превращает grp:ralt_toggle в Alt/Alt_R/ISO_Level3_Shift etc.,
    # поэтому используем более устойчивый regexp и нормализуем строку так,
    # чтобы правая Alt (keycode 100) стал AltGr_Lock в keymap консоли.
    sed -E -i 's/^[[:space:]]*keycode[[:space:]]+100[[:space:]]*=.*/keycode 100 = AltGr_Lock/' "$out"
  '';
in
{
  console = {
    useXkbConfig = lib.mkDefault false;
    earlySetup = lib.mkDefault true;
    font = lib.mkDefault ttyFont;
    keyMap = lib.mkDefault ruConsoleKeymap;
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
