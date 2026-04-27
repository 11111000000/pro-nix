# test-basic-activation.nix — минимальный тест активации
{ testers, ... }:

testers.nixosTest {
  name = "basic-activation-test";

  nodes.machine = { config, pkgs, lib, ... }: {
    imports = [ ../../modules/pro-privacy.nix ];

    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = false;

    services.xserver.enable = lib.mkForce false;
    services.displayManager.enable = lib.mkForce false;

    virtualisation.memorySize = 1024;
    virtualisation.cores = 1;
    virtualisation.diskSize = 4096;

    services.openssh.enable = true;
  };

  testScript = ''
    start_all();
    \$machine->waitForUnit("multi-user.target");
    \$machine->sleep(5);

    # Проверка unit-файлов
    \$machine->succeed("systemd-analyze verify /etc/systemd/system/tor-ensure-bridges.service 2>&1");
    \$machine->succeed("systemd-analyze verify /etc/systemd/system/tor-ensure-perms.service 2>&1");

    # Проверка отсутствия Unbalanced quoting
    my \$out = \$machine->execute("journalctl -b0 | grep -i 'Unbalanced quoting' || true");
    if (\$out =~ /Unbalanced quoting/) {
      die "Unbalanced quoting found: \$out";
    }

    # Проверка ExecStart
    my \$exec = \$machine->succeed("grep ExecStart /etc/systemd/system/tor-ensure-bridges.service");
    if (\$exec !~ /\/nix\/store/) {
      die "ExecStart missing /nix/store: \$exec";
    }

    print "=== TEST PASSED ===\n";
  '';
}
