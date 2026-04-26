# Название: modules/systemd-policy.nix — Политика запуска systemd-служб
# Summary (EN): D-Bus and polkit service ordering policies
# Цель:
#   Задать явный порядок запуска systemd-служб (dbus, polkit) для
#   минимизации race conditions при live switch.
# Контракт:
#   Опции: services.dbus.implementation
#   Побочные эффекты: настраивает order для polkit после dbus.
# Предпосылки:
#   Требуется systemd (любая современная версия NixOS).
# Как проверить (Proof):
#   `systemctl status polkit` — должен быть active после dbus
# Last reviewed: 2026-04-27
{ config, lib, pkgs, ... }:

{
  # KEY FIX: Use classic dbus instead of dbus-broker.
  # dbus-broker is faster but has more race conditions during switch because
  # it re-registers its name on the bus more aggressively.
  # Classic dbus is more stable during transitions.
  services.dbus = {
    enable = true;
    implementation = lib.mkDefault "dbus";
  };

  # Обеспечиваем явный порядок для polkit - ensures proper startup ordering.
  # This is the key: polkit must wait for dbus to be FULLY ready,
  # not just started. Using "dbus.service" as the literal unit name
  # guarantees ordering after the classic dbus daemon.
  systemd.services.polkit = {
    # CRITICAL: Wait for dbus to be ready. Using both the service name
    # and ensuring we're after sysinit-reactivation.target which is used
    # during live switch to serialize reconfiguration.
    after = [
      "dbus.service"
      "sysinit-reactivation.target"
    ];
    wants = [ "dbus.service" ];
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };

}
