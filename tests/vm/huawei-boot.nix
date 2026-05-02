{ testers, home-manager, ... }:

testers.nixosTest {
  name = "huawei-boot";

  nodes.machine = { ... }: {
    imports = [
      home-manager
      ../../configuration.nix
      ../../hosts/huawei/vm-boot.nix
    ];
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")
    machine.sleep(20)

    journal = machine.succeed("journalctl -b --no-pager")

    if "Got disconnect on API bus" in journal:
        raise Exception("systemd lost API bus during boot")

    if "Failed to activate service 'org.freedesktop.systemd1'" in journal:
        raise Exception("system bus failed to activate org.freedesktop.systemd1")

    if "parse failure" in journal:
        raise Exception("avahi service parse failure detected")

    machine.succeed("systemctl is-active dbus-broker")
    machine.succeed("systemctl is-active NetworkManager")

    print("=== HUAWEI BOOT TEST PASSED ===")
  '';
}
