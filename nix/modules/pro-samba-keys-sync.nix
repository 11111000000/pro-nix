{ lib, pkgs, ... }:

{
  # Install the sync helper script for encrypted creds distribution.
  environment.etc."pro-samba-sync-keys.sh".source = ../../scripts/pro-samba-sync-keys.sh;
  environment.etc."pro-samba-sync-keys.sh".mode = "0755";

  # Provide a systemd oneshot used by pro-peer-master to deploy and activate creds.
  systemd.services."pro-samba-sync-keys" = {
    description = "Apply decrypted samba creds to /etc/samba/creds.d";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "/etc/pro-samba-sync-keys.sh --input /tmp/authorized_creds.gpg --out /etc/samba/creds.d/%i";
      RemainAfterExit = "no";
    };
  };
}
