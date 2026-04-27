# test-vm-boot.nix — проверка загрузки VM без ребута
{ testers, ... }:

testers.nixosTest {
  name = "vm-boot-test";
  
  nodes.machine = { config, pkgs, lib, ... }: {
    imports = [ ./hosts/huawei/configuration.nix ];
    
    # Минимальная конфигурация для VM
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = false;
    
    # Отключаем графику
    services.xserver.enable = lib.mkForce false;
    services.displayManager.enable = lib.mkForce false;
    services.gdm.enable = lib.mkForce false;
    
    # Минимальные ресурсы VM
    virtualisation.memorySize = 1024;
    virtualisation.cores = 1;
    virtualisation.diskSize = 4096;
    
    # SSH для отладки
    services.openssh.enable = true;
  };
  
  testScript = ''
    # Минимальный Perl-синтаксис, без сложных конструкций
    start_all();
    
    # Ждём загрузки
    $machine->waitForUnit("multi-user.target");
    $machine->sleep(10);
    
    # Проверяем, что система не перезагружалась (uptime больше 30 секунд)
    my $uptime = $machine->succeed("cat /proc/uptime | awk '{print \$1}'");
    if ($uptime < 30) {
      die "System rebooted too quickly, uptime: $uptime";
    }
    
    # Проверяем, что tor-ensure сервисы не имеют Unbalanced quoting
    my $out = $machine->execute("journalctl -b0 | grep -i 'Unbalanced quoting' || true");
    if ($out =~ /Unbalanced quoting/) {
      die "Found Unbalanced quoting: $out";
    }
    
    # Проверяем, что samba.service не имеет parse failure
    $out = $machine->execute("journalctl -b0 | grep -i 'parse failure' || true");
    if ($out =~ /parse failure/) {
      die "Found parse failure: $out";
    }
    
    print "=== VM BOOT TEST PASSED ===\n";
  '';
}
