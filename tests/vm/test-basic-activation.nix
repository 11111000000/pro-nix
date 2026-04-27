# test-basic-activation.nix — минимальный тест активации базовых юнитов
# Проверяет отсутствие Unbalanced quoting и корректность unit-файлов
{ testers, ... }:

testers.nixosTest {
  name = "basic-activation-test";

  nodes = {
    machine = { config, pkgs, lib, ... }: {
      imports = [ ../../modules/pro-privacy.nix ];

      # Базовая система для VM
      boot.loader.systemd-boot.enable = true;
      boot.loader.efi.canTouchEfiVariables = false;

      # Отключаем графический стек
      services.xserver.enable = lib.mkForce false;
      services.displayManager.enable = lib.mkForce false;

      # Минимальный размер VM
      virtualisation.memorySize = 1024;
      virtualisation.cores = 1;
      virtualisation.diskSize = 4096;

      # SSH для отладки
      services.openssh.enable = true;
    };
  };

  testScript = ''
    # Запуск машины
    start_all();

    # Ждем загрузки
    $machine->waitForUnit("multi-user.target");

    # Даем время на стабилизацию
    $machine->sleep(10);

    # Проверка 1: unit-файлы проходят systemd-analyze verify
    $machine->succeed("systemd-analyze verify /etc/systemd/system/tor-ensure-bridges.service 2>&1");
    $machine->succeed("systemd-analyze verify /etc/systemd/system/tor-ensure-perms.service 2>&1");

    # Проверка 2: отсутствие Unbalanced quoting в логах
    my $unbalanced = $machine->execute("journalctl --boot=0 | grep -i 'Unbalanced quoting' || true");
    if ($unbalanced =~ /Unbalanced quoting/) {
      die "Found Unbalanced quoting in logs: $unbalanced";
    }

    # Проверка 3: файлы существуют
    $machine->succeed("test -f /etc/systemd/system/tor-ensure-bridges.service");
    $machine->succeed("test -f /etc/systemd/system/tor-ensure-perms.service");

    # Проверка 4: ExecStart содержит явный путь
    my $bridges_exec = $machine->succeed("grep ExecStart /etc/systemd/system/tor-ensure-bridges.service");
    if ($bridges_exec =~ /\/bin\/sh -c/) {
      die "Found /bin/sh -c in ExecStart: $bridges_exec";
    }
    if ($bridges_exec !~ /\/nix\/store/) {
      die "ExecStart should contain /nix/store path: $bridges_exec";
    }

    print "=== ВСЕ ПРОВЕРКИ ПРОЙДЕНЫ ===\n";
  '';
}
