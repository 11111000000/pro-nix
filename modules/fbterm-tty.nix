{ pkgs, lib, ... }:

{
  # Fbterm service for a chosen TTY (example: tty2). This runs fbterm which
  # renders TrueType fonts via fontconfig and provides smoother fonts and
  # improved colors compared to the classic Linux VT.

  # Note: enable this per-host by importing this module or copy the service
  # definition into host configuration. Test on one machine first.

  systemd.services.fbterm-tty2 = {
    description = "Fbterm on tty2 (login)";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      # Start on tty2 and run login inside fbterm
      ExecStart = "${pkgs.fbterm}/bin/fbterm -s 2 -e /bin/login";
      Restart = "always";
      StandardInput = "tty";
      StandardOutput = "tty";
      TTYPath = "/dev/tty2";
    };
    # Make sure fbterm runs after KMS and getty so tty device is ready.
    after = [ "getty@tty2.service" ];
  };

}
