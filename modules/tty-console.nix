{ pkgs, lib, config, ... }:

/*
Change Gate
Intent: Сделать TTY-шрифт и раскладку виртуальной консоли безопасными для активации.
Pressure: Ops
Surface impact: NixOS Base Configuration [FROZEN] — виртуальные консоли получают
                общий UTF-8 шрифт и раскладку через XKB без зависимости от desktop-модулей.
Proof: `systemd-analyze verify /etc/systemd/system/systemd-vconsole-setup.service`
       и проверка `nix eval --json .#nixosConfigurations.<host>.config.console.useXkbConfig`.
Migration: none.
*/

let
  ttyFont = "${pkgs.kbd}/share/consolefonts/Cyr_a8x14.psfu.gz";
in
{
  console = {
    # tty должен повторять XKB-раскладку из services.xserver.xkb.
    useXkbConfig = lib.mkDefault true;
    earlySetup = lib.mkDefault true;
    font = lib.mkDefault ttyFont;
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
