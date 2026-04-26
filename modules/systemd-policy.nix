# Название: modules/systemd-policy.nix — Политика запуска systemd-служб
# Summary (EN): D-Bus and polkit service ordering policies
# Цель:
#   Задать явный порядок запуска systemd-служб (dbus-broker, polkit) для
#   минимизации рекурсивных зависимостей при оценке модулей.
# Контракт:
#   Опции: services.dbus.implementation
#   Побочные эффекты: настраивает order для polkit после dbus.
# Предпосылки:
#   Требуется systemd (любая современная версия NixOS).
# Как проверить (Proof):
#   `systemctl status polkit` — должен быть active после dbus
# Last reviewed: 2026-04-25
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
     # Ensure polkit is ordered after the system bus (dbus-broker) and
     # the reactivation target used during live switch. Use unit-level
     # attributes `after`/`wants` so they land in [Unit] of the generated
     # service file (not in [Service]). This reduces the window where
     # polkit restarts while the system bus is not yet ready.
     after = [ "dbus.service" "dbus-broker.service" "sysinit-reactivation.target" ];
     wants = [ "dbus.service" "dbus-broker.service" ];
     serviceConfig = {
       Restart = "on-failure";
       RestartSec = "3s";
     };
   };

}
