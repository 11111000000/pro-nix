{ lib, pkgs, ... }:

{
  # Provide a systemd user template to mount smb shares on demand if requested.
  systemd.user.services."mount-smb@" = {
    description = "Mount SMB share for %i (template)";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = "no";
    };
    wantedBy = [ "default.target" ];
    script = ''
      cmd=/run/current-system/sw/bin/bash
      exec $cmd -c "${pkgs.writeShellScript "mount-smb-wrapper" ''/bin/true''}/bin/mount-smb.sh mount %i"
    '';
  };
}
