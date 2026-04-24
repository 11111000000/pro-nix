{ config, pkgs, lib, ... }:

{
  # Use dbus-broker for more robust brokered system bus behavior
  services.dbus.implementation = "broker";

  # Ensure polkit starts/restarts after the system bus is ready to avoid a
  # transient window where D-Bus rejects method calls during activation.
  systemd.services.polkit.after = lib.mkForce [ "dbus.service" "sysinit-reactivation.target" ];
  systemd.services.polkit.wants = lib.mkForce [ "dbus.service" ];
  # Small restart delay to give dbus time to settle after reloads/reexecs.
  systemd.services.polkit.serviceConfig = (config.systemd.services.polkit.serviceConfig or {}) // {
    RestartSec = "3s";
  };

  # Limit the nix-daemon so it doesn't saturate CPU on desktop machines.
  systemd.services."nix-daemon".serviceConfig = (config.systemd.services."nix-daemon".serviceConfig or {}) // {
    CPUQuota = "75%";
    CPUWeight = "200";
  };
}
