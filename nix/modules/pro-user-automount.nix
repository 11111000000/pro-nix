{ lib, pkgs, ... }:

/* RU: Файловый контракт — nix/modules/pro-user-automount.nix
   Кратко: systemd user-level templates и обёртки для автоматического монтирования SMB
   под $HOME/mnt/hosts/<host>.

   Цель: предоставить проверяемые user-level unit-шаблоны, где ExecStart ссылается
     на store-путь, чтобы `systemd-analyze verify` мог разрешить путь.

   Контракт: экспорт environment.etc."systemd/user/smb-mount-user@.service" и
     соответствующий automount, а также helper script в /usr/local/bin.

   Proof: `systemd-analyze verify --user /run/user/$(id -u)/system/smb-mount-user@.service`
*/

let
  helpers = {
    mountSmbUser = pkgs.writeShellScriptBin "mount-smb-user" ''
      #!/usr/bin/env bash
      set -euo pipefail
      exec /run/current-system/sw/bin/bash /etc/usr/local/bin/mount-smb-user "$@"
    '';
  };

{
  # Optional systemd user automount template: mounts under $HOME/mnt/hosts/<host>
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

  # Install a user-facing wrapper that calls repo script
  environment.etc."usr/local/bin/mount-smb-user".text = ''
  #!/usr/bin/env bash
  exec "${./scripts/mount-smb.sh}" "$@"
  '';
  environment.etc."usr/local/bin/mount-smb-user".mode = "0755";
}
