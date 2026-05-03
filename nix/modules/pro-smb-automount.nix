{ lib, pkgs, ... }:

/* RU: Файловый контракт — nix/modules/pro-smb-automount.nix
   Кратко: шаблоны systemd unit'ов и вспомогательные wrapper-скрипты для
   автоматического монтирования SMB-ресурсов с помощью repo-скрипта.

   Цель: предоставить проверяемые unit-шаблоны, где ExecStart указывает на
     конкретный путь в store, чтобы `systemd-analyze verify` мог разрешить путь.

   Контракт: экспорт environment.etc."systemd/system/smb-mount@.service" и
     соответствующий automount unit, а также helper script в /usr/local/bin.

   Proof: `systemd-analyze verify /run/current-system/system/smb-mount@.service`
*/

let
  # Create a small store-installed helper so ExecStart references a concrete
  # /nix/store path (avoids embedding writeShellScriptBin directly in the unit
  # text which can yield unbalanced quoting). The helper forwards to the
  # operator-provided script in /etc.
  helpers = {
    mountSmbWrapper = pkgs.writeShellScriptBin "mount-smb-wrapper" ''/usr/local/bin/mount-smb-wrapper'';
  };

{
  # Install system-level systemd unit templates for SMB automounting.
  # They mount to /mnt/hosts/<host> and call the helper script added in the repo.
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

  # Install a small wrapper into /usr/local/bin that invokes the repo script.
  environment.etc."usr/local/bin/mount-smb-wrapper".text = ''
  #!/usr/bin/env bash
  exec "${./scripts/mount-smb.sh}" "$@"
  '';
  environment.etc."usr/local/bin/mount-smb-wrapper".mode = "0755";
}
