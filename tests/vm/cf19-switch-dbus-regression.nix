{ testers, ... }:

# VM regression test for the DBus live-switch cascade.
# Контракт: внутри изолированной VM имитируем именно switch-ошибку на уровне
# systemd Manager API и проверяем, что после reload D-Bus продолжает отвечать
# на запросы `ListUnits` без потери доступа к org.freedesktop.systemd1.Manager.
testers.nixosTest {
  name = "cf19-switch-dbus-regression";

  nodes.machine = { lib, ... }: {
    networking.hostName = "cf19-vm";
    system.stateVersion = "25.11";

    fileSystems."/" = {
      device = "/dev/vda1";
      fsType = "ext4";
    };

    boot.loader.grub.enable = lib.mkForce false;
    boot.loader.systemd-boot.enable = lib.mkForce true;
    boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

    services.dbus.enable = true;
    services.dbus.implementation = lib.mkDefault "dbus";
    users.groups.netdev = { };
    systemd.services.dbus.reloadIfChanged = lib.mkDefault false;
    systemd.services.dbus.restartIfChanged = lib.mkDefault false;
    systemd.services.dbus.stopIfChanged = lib.mkDefault false;

    virtualisation.memorySize = 1024;
    virtualisation.cores = 1;
    virtualisation.diskSize = 4096;
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("dbus.service")

    # Baseline journal for diagnostics.
    machine.succeed("journalctl -b --no-pager | tail -n 200 > /tmp/cf19-before.log")
    machine.succeed("systemctl is-active dbus")
    machine.succeed("busctl --system call org.freedesktop.systemd1 /org/freedesktop/systemd1 org.freedesktop.DBus.Peer Ping >/tmp/cf19-ping-before.log")
    machine.succeed("busctl --system call org.freedesktop.systemd1 /org/freedesktop/systemd1 org.freedesktop.systemd1.Manager ListUnits >/tmp/cf19-list-units-before.log")

    # Switch-like stressor: reload systemd state and immediately re-check that
    # D-Bus still resolves the systemd manager object.
    machine.succeed("systemctl daemon-reload")
    machine.succeed("busctl --system call org.freedesktop.systemd1 /org/freedesktop/systemd1 org.freedesktop.DBus.Peer Ping >/tmp/cf19-ping-after.log")
    machine.succeed("busctl --system call org.freedesktop.systemd1 /org/freedesktop/systemd1 org.freedesktop.systemd1.Manager ListUnits >/tmp/cf19-list-units-after.log")

    after = machine.succeed("journalctl -b --no-pager | tail -n 300")
    if "Rejected send message" in after:
        raise Exception("DBus cascade reproduced in VM regression test")
    if "No such interface 'org.freedesktop.systemd1.Manager'" in after:
        raise Exception("systemd manager interface vanished in VM regression test")

    print("=== CF19 DBUS SWITCH REGRESSION TEST PASSED ===")
  '';
}
