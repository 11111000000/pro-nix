{ config, lib, pkgs, ... }:

{
  # Use dbus-broker which tends to be faster to re-acquire the bus name and
  # reduces the window where clients see a missing system bus during reloads.
  services.dbus = lib.mkIf true {
    enable = true;
    implementation = "broker";
  };

  # Обеспечиваем явный порядок для polkit, не читая текущую config.*-структуру
  # чтобы избежать рекурсивных зависимостей при оценке модулей. Другие модули
  # могут дополнять поля systemd.services.polkit через стандартные механизмы
  # слияния модулей; здесь мы лишь задаём минимальные необходимые поля.
  systemd.services.polkit = {
    after = [ "dbus.service" "sysinit-reactivation.target" ];
    wants = [ "dbus.service" ];
    serviceConfig = {
      RestartSec = "3s";
    };
  };

}
