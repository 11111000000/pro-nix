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
    
    # Отключаем tor в тесте
    services.tor.enable = lib.mkForce false;
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")
    machine.sleep(5)
    
    # Проверка unit-файлов
    machine.succeed("systemd-analyze verify /etc/systemd/system/tor-ensure-bridges.service 2>&1")
    machine.succeed("systemd-analyze verify /etc/systemd/system/tor-ensure-perms.service 2>&1")
    
    # Проверка отсутствия Unbalanced quoting
    out = machine.execute("journalctl -b0 | grep -i 'Unbalanced quoting' || true")[1]
    if "Unbalanced quoting" in out:
        raise Exception("Unbalanced quoting found: " + out)
    
    # Проверка ExecStart
    exec_out = machine.succeed("grep ExecStart /etc/systemd/system/tor-ensure-bridges.service")
    if "/bin/sh -c" in exec_out:
        raise Exception("Wrong ExecStart: " + exec_out)
    if "/nix/store" not in exec_out:
        raise Exception("ExecStart missing /nix/store: " + exec_out)
    
    print("=== TEST PASSED ===")
  '';
}
