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
    # Use a concrete helper path instead of embedding writeShellScript in a -c invocation
    script = ''
      exec /run/current-system/sw/bin/bash ${pkgs.writeShellScriptBin "mount-smb-wrapper" ''/usr/local/bin/mount-smb-wrapper''}/bin/mount-smb-wrapper mount %i
    '';
  };
}
