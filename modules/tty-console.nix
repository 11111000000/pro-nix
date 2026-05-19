{ pkgs, lib, ... }:

/*
Change Gate
Intent: Сделать TTY-шрифт и переключение en/ru по Right Alt общей политикой всех хостов.
Pressure: Ops
Surface impact: NixOS Base Configuration [FROZEN] — виртуальные консоли получают
                общий UTF-8 шрифт и keymap без зависимости от desktop-модулей.
Proof: `nix eval --json .#nixosConfigurations.<host>.config.systemd.services.load-tty-keymap`
       и `nix build .#nixosConfigurations.<host>.config.system.build.toplevel`.
Migration: none.
*/

let
  ttyKeymap = "${pkgs.kbd}/share/keymaps/i386/qwerty/ruwin_alt-UTF-8.map.gz";
  ttyFont = "${pkgs.kbd}/share/consolefonts/latarcyrheb-sun16.psfu.gz";
in
{
  console.useXkbConfig = lib.mkDefault true;
  console.earlySetup = lib.mkDefault true;
  console.font = lib.mkDefault ttyFont;

  # Linux console не применяет XKB option `grp:ralt_toggle` напрямую.
  # Поэтому keymap для TTY загружается отдельным unit-ом через loadkeys.
  systemd.services.load-tty-keymap = {
    description = "Загрузить TTY keymap: Right Alt переключает ru/en";
    wantedBy = [ "multi-user.target" ];
    before = [ "getty@tty1.service" "getty@tty2.service" "getty@tty3.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.kbd}/bin/loadkeys ${ttyKeymap}";
    };
  };

  systemd.services."getty@tty2".enable = lib.mkDefault true;
  systemd.services."getty@tty3".enable = lib.mkDefault true;

  systemd.services.kbdrate = {
    description = "Задание интервалов повторения на виртуальной консоли";
    wantedBy = [ "multi-user.target" ];
    after = [ "load-tty-keymap.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.kbd}/bin/kbdrate -d 250 -r 30";
    };
  };
}
