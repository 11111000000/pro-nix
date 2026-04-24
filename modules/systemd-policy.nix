{ config, lib, pkgs, ... }:

{
  # Use dbus-broker which tends to be faster to re-acquire the bus name and
  # reduces the window where clients see a missing system bus during reloads.
  services.dbus = lib.mkIf true {
    enable = true;
    implementation = "broker";
  };

  # Ensure polkit has explicit Unit ordering so it does not restart before
  # dbus is available during a live switch / activation.
  systemd.services.polkit = lib.mkMerge [ (config.systemd.services.polkit or {}) {
    after = [ "dbus.service" "sysinit-reactivation.target" ];
    wants = [ "dbus.service" ];
    # Keep a short restart delay to allow dbus to stabilize on reload.
    serviceConfig = (config.systemd.services.polkit.serviceConfig or {}) // {
      RestartSec = "3s";
    };
  } ];

}
