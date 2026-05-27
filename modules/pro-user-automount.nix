{ lib, pkgs, ... }:

# RU: Файловый контракт — modules/pro-user-automount.nix
#    Кратко: systemd user-level templates и обёртки для автоматического монтирования SMB
#    под $HOME/mnt/hosts/<host>.

let
  helpers = {
    mountSmbUser = pkgs.writeShellScriptBin "mount-smb-user" ''
      #!/usr/bin/env bash
      set -euo pipefail
      exec /run/current-system/sw/bin/bash /etc/usr/local/bin/mount-smb-user "$@"
    '';
  };

in
{
  environment.etc."systemd/user/smb-mount-user@.service".text = ''
  [Unit]
  Description=Mount SMB share for %i (user)
  After=network-online.target

  [Service]
  Type=oneshot
   # Use a store-installed helper so ExecStart is a concrete path and
   # `systemd-analyze verify` can validate it reliably.
   ExecStart = "${helpers.mountSmbUser}/bin/mount-smb-user";
  '';

  environment.etc."systemd/user/smb-mount-user@.automount".text = ''
  [Automount]
  Where=%h/mnt/hosts/%i
  TimeoutIdleSec=120
  '';

  environment.etc."usr/local/bin/mount-smb-user".text = ''
  #!/usr/bin/env bash
  exec "${../scripts/ops-mount-smb.sh}" "$@"
  '';
  environment.etc."usr/local/bin/mount-smb-user".mode = "0755";
}
