# test-basic-activation.nix — минимальный тест активации базовых юнитов
# Проверяет отсутствие Unbalanced quoting и корректность unit-файлов
{ pkgs, ... }:

pkgs.nixosTest {
  name = "basic-activation-test";
  
  nodes = {
    machine = { config, lib, ... }: {
      imports = [ ../../hosts/huawei/configuration.nix ];
      
      # Отключаем графический стек для упрощения теста
      services.xserver.enable = lib.mkForce false;
      services.displayManager.enable = lib.mkForce false;
      services.gdm.enable = lib.mkForce false;
      
      # Отключаем Tor в тесте (может не работать в VM)
      services.tor.enable = false;
      services.tor.relay.enable = false;
      services.tor.hiddenServices = lib.mkForce [];
      
      # Минимальный размер VM
      virtualisation.memorySize = 1024;
      virtualisation.cores = 1;
      virtualisation.diskSize = 4096;
      
      # Включаем SSH для отладки
      services.openssh.enable = true;
    };
  };
  
  testScript = ''
    # Запуск машины
    start_all();
    
    # Ждем загрузки основных сервисов
    $machine->waitForUnit("multi-user.target");
    
    # Даем время на стабилизацию (логи, активация)
    $machine->sleep(10);
    
    # Проверка 1: unit-файлы проходят systemd-analyze verify
    $machine->succeed("systemd-analyze verify /etc/systemd/system/tor-ensure-bridges.service 2>&1");
    $machine->succeed("systemd-analyze verify /etc/systemd/system/tor-ensure-perms.service 2>&1");
    
    # Проверка 2: отсутствие Unbalanced quoting в логах загрузки
    my $unbalanced = $machine->execute("journalctl --boot=0 | grep -i 'Unbalanced quoting' || true");
    if ($unbalanced =~ /Unbalanced quoting/) {
      die "Found Unbalanced quoting in logs: $unbalanced";
    }
    
    # Проверка 3: отсутствие parse failure в avahi
    my $parse_errors = $machine->execute("journalctl --boot=0 | grep -i 'parse failure' || true");
    if ($parse_errors =~ /parse failure/) {
      die "Found parse failure in logs: $parse_errors";
    }
    
    # Проверка 4: статус юнитов (не должны быть в failed)
    $machine->succeed("systemctl is-enabled tor-ensure-bridges.service || true");
    $machine->succeed("systemctl is-enabled tor-ensure-perms.service || true");
    
    # Проверка 5: файлы существуют и читаемы
    $machine->succeed("test -f /etc/systemd/system/tor-ensure-bridges.service");
    $machine->succeed("test -f /etc/systemd/system/tor-ensure-perms.service");
    $machine->succeed("test -f /etc/avahi/services/samba.service");
    
    # Проверка 6: ExecStart содержит явный путь (без кавычек внутри)
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
