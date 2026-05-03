{ lib, pkgs, ... }:

/* RU: Файловый контракт (nix/modules/pro-samba-keys-sync.nix)
   Кратко: устанавливает необходимые скрипты-обёртки и systemd oneshot для
   применения расшифрованных учётных данных samba в /etc/samba/creds.d.

   Цель: обеспечить детерминированное и проверяемое размещение скриптов и
     systemd-юнита, избегая inline-строк в ExecStart и проблем с кавычками.

   Контракт: экспортировать environment.etc.<..> и systemd.services.pro-samba-sync-keys
   без принудительного изменения других модулей. Использовать абсолютные пути
   к некоторым скриптам для `systemd-analyze verify`.

   Proof: `systemd-analyze verify /run/current-system/system/pro-samba-sync-keys.service`
*/

let
  # Provide a small store-installed helper so ExecStart references a concrete
  # path in /nix/store rather than embedding a complex inline invocation.
  # This keeps the resulting unit verifiable with `systemd-analyze verify`.
  helpers = {
    proSambaSync = pkgs.writeShellScriptBin "pro-samba-sync-keys-wrapper" ''
      #!/usr/bin/env bash
      set -euo pipefail
      # Delegate to the /etc-installed wrapper which contains operator-provided
      # logic. Using exec preserves exit code semantics for systemd.
      exec /run/current-system/sw/bin/bash /etc/pro-samba-sync-keys-wrapper.sh "$@"
    '';
  };

{
  # Install the sync helper script for encrypted creds distribution.
  environment.etc."pro-samba-sync-keys.sh".source = ../../scripts/pro-samba-sync-keys.sh;
  environment.etc."pro-samba-sync-keys.sh".mode = "0755";

  # Install a thin wrapper that normalizes invocation and avoids inline ExecStart quoting.
  environment.etc."pro-samba-sync-keys-wrapper.sh".source = ../../scripts/pro-samba-sync-keys-wrapper.sh;
  environment.etc."pro-samba-sync-keys-wrapper.sh".mode = "0755";

  # Provide a systemd oneshot used by pro-peer-master to deploy and activate creds.
  systemd.services."pro-samba-sync-keys" = {
    description = "Apply decrypted samba creds to /etc/samba/creds.d";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${helpers.proSambaSync}/bin/pro-samba-sync-keys-wrapper --input /tmp/authorized_creds.gpg --out /etc/samba/creds.d/%i";
      RemainAfterExit = "no";
    };
  };
}
