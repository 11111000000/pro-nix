{ lib, pkgs, ... }:

{
  # Optional systemd user automount template: mounts under $HOME/mnt/hosts/<host>
  environment.etc."systemd/user/smb-mount-user@.service".text = ''
  [Unit]
  Description=Mount SMB share for %i (user)
  After=network-online.target

  [Service]
  Type=oneshot
  ExecStart=/run/current-system/sw/bin/bash -c '${pkgs.writeShellScriptBin "mount-smb-user" ''/home/placeholder''}'
  '';

  environment.etc."systemd/user/smb-mount-user@.automount".text = ''
  [Automount]
  Where=%h/mnt/hosts/%i
  TimeoutIdleSec=120
  '';

  # Install a user-facing wrapper that calls repo script
  environment.etc."usr/local/bin/mount-smb-user".text = ''
  #!/usr/bin/env bash
  exec "${./scripts/mount-smb.sh}" "$@"
  '';
  environment.etc."usr/local/bin/mount-smb-user".mode = "0755";
}
