{ lib, pkgs, ... }:

# RU: Файловый контракт — modules/pro-smb-automount.nix
#   Кратко: шаблоны systemd unit'ов и вспомогательные wrapper-скрипты для
#   автоматического монтирования SMB-ресурсов с помощью repo-скрипта.

let
  helpers = {
    mountSmbWrapper = pkgs.writeShellScriptBin "mount-smb-wrapper" ''/usr/local/bin/mount-smb-wrapper'';
  };

in
{
  environment.etc."systemd/system/smb-mount@.service".text = ''
  [Unit]
  Description=Mount SMB share for %i
  After=network-online.target
  Wants=network-online.target

  [Service]
  Type=oneshot
  RemainAfterExit=no
   # Use a store-installed helper so ExecStart is a concrete path and avoids
   # complex quoting inside the unit. Reference the helper created above.
   ExecStart = "${helpers.mountSmbWrapper}/bin/mount-smb-wrapper mount %i";
  ExecStop=/run/current-system/sw/bin/umount /mnt/hosts/%i
  '';

  environment.etc."systemd/system/smb-mount@.automount".text = ''
  [Unit]
  Description=Automount SMB share for %i

  [Automount]
  Where=/mnt/hosts/%i
  TimeoutIdleSec=120

  [Install]
  WantedBy=multi-user.target
  '';

  environment.etc."usr/local/bin/mount-smb-wrapper".text = ''
  #!/usr/bin/env bash
  exec "${../scripts/ops-mount-smb.sh}" "$@"
  '';
  environment.etc."usr/local/bin/mount-smb-wrapper".mode = "0755";
}
