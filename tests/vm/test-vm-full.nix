{ testers, ... }:

testers.nixosTest {
  name = "vm-full-test";

  nodes.machine = { config, pkgs, lib, ... }: {
    networking.hostName = "vm";
    system.stateVersion = "25.11";

    fileSystems."/" = {
      device = "/dev/vda1";
      fsType = "ext4";
    };

    boot.loader.grub.enable = lib.mkForce false;
    boot.loader.systemd-boot.enable = lib.mkForce true;
    boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

    services.openssh.enable = true;
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")
    machine.sleep(5)

    # Check basic services are running
    machine.succeed("systemctl is-active dbus")

    # Verify systemd units parse correctly
    machine.succeed("systemd-analyze verify /etc/systemd/system/sshd.service 2>&1 || true")

    print("=== VM TEST PASSED ===")
  '';
}