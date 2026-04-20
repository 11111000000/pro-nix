{ config, pkgs, lib, ... }:

let
  cfg = {};
in

{
  options = {
    pro-peer = {
      enable = lib.mkEnableOption "Enable pro peer discovery defaults (Avahi + SSH hardening)";
      allowTorHiddenService = lib.mkEnableOption "Enable tor hidden-service example for SSH (off by default)";
      enableKeySync = lib.mkEnableOption "Enable automatic authorized_keys sync from an encrypted file";
      keysGpgPath = lib.mkOption {
        type = lib.types.str;
        description = "Path to GPG-encrypted authorized_keys (default: /etc/pro-peer/authorized_keys.gpg)";
        default = "/etc/pro-peer/authorized_keys.gpg";
      };
      keySyncInterval = lib.mkOption {
        type = lib.types.str;
        description = "Systemd timer OnCalendar/OnUnitActiveSec for key sync (default: 1h)";
        default = "1h";
      };
      torBackupRecipient = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        description = "GPG recipient to encrypt HiddenService backup to (optional).";
        default = null;
      };
      enableYggdrasil = lib.mkEnableOption "Enable Yggdrasil mesh daemon (optional)";
      yggdrasilConfigPath = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        description = "Path to yggdrasil config file (optional). If null a default will be used in /etc/yggdrasil.conf";
        default = null;
      };
      enableWireguardHelper = lib.mkEnableOption "Enable simple WireGuard helper (wg-quick) (optional)";
      wireguardConfigPath = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        description = "Path to wireguard config (wg0.conf) to be used by helper service";
        default = null;
      };
    };
  };

  # Collect conditional fragments and merge them into a single `config` attribute
  config = lib.mkMerge [
    (lib.mkIf config.pro-peer.enable {
      # Avahi for mDNS host discovery in LAN
      services.avahi = {
        enable = true;
      };

      # SSH hardening defaults for pro-nix peers
      services.openssh = {
        enable = true;
        settings = {
          PermitRootLogin = "no";
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
        };
      };

      # Ensure directory and placeholder authorized_keys file exist with secure permissions
      # Note: tmpfiles rule creation was removed in favor of explicit provisioning.

      # Avoid the NixOS sshd module reading arbitrary files at evaluation time by
      # forcing root's authorizedKeys keyFiles to an empty list. The actual
      # authorized_keys is managed at runtime by the pro-peer sync service.
      users.users.root.openssh.authorizedKeys = lib.mkForce { keys = []; keyFiles = []; };
    })

    (lib.mkIf config.pro-peer.enableKeySync {
      environment.systemPackages = with pkgs; [ gnupg ];
      environment.etc."pro-peer-sync-keys.sh".source = ../scripts/pro-peer-sync-keys.sh;
      environment.etc."pro-peer-sync-keys.sh".mode = "0755";

      systemd.services."pro-peer-sync-keys" = {
        description = "Pro‑peer: sync authorized_keys from encrypted file";
        wantedBy = [ "multi-user.target" ];
        # Limit CPU usage of this occasional oneshot task so it cannot
        # saturate interactive sessions when it runs (small conservative quota).
        serviceConfig = {
          Type = "oneshot";
          ExecStart = builtins.concatStringsSep " " [ "/etc/pro-peer-sync-keys.sh" "--input" config.pro-peer.keysGpgPath "--out" "/var/lib/pro-peer/authorized_keys" ];
          CPUAccounting = "true";
          CPUQuota = "30%";
        };
      };

      systemd.timers."pro-peer-sync-keys.timer" = {
        description = "Periodic pro-peer key sync";
        timerConfig = { OnUnitActiveSec = config.pro-peer.keySyncInterval; };
        wantedBy = [ "timers.target" ];
      };
    })

    (lib.mkIf (config.pro-peer.allowTorHiddenService && (config.pro-peer.torBackupRecipient != null)) {
      environment.systemPackages = with pkgs; [ gnupg tar ];
      environment.etc."pro-peer-backup-hiddenservice.sh".source = ../scripts/backup-hiddenservice.sh;
      environment.etc."pro-peer-backup-hiddenservice.sh".mode = "0755";

      systemd.services."pro-peer-backup-hiddenservice" = {
        description = "Backup tor hidden service key encrypted to recipient";
        after = [ "tor.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = builtins.concatStringsSep " " [ "/etc/pro-peer-backup-hiddenservice.sh" "--hidden-dir" "/var/lib/tor/ssh_hidden_service" "--recipient" config.pro-peer.torBackupRecipient "--out-dir" "/var/lib/pro-peer" ];
          CPUAccounting = "true";
          CPUQuota = "30%";
        };
      };
    })

    (lib.mkIf config.pro-peer.enableYggdrasil {
      environment.systemPackages = with pkgs; [ yggdrasil ];
      systemd.services.yggdrasil = {
        description = "Yggdrasil mesh daemon (pro-peer)";
        wantedBy = [ "multi-user.target" ];
        # Give the mesh daemon a modest share of CPU but prevent it from
        # saturating the machine during heavy network activity.
        serviceConfig = {
          ExecStart = builtins.concatStringsSep " " [ (builtins.toString pkgs.yggdrasil + "/bin/yggdrasil") "-useconffile" (if config.pro-peer.yggdrasilConfigPath != null then config.pro-peer.yggdrasilConfigPath else "/etc/yggdrasil.conf") ];
          Restart = "on-failure";
          CPUAccounting = "true";
          CPUQuota = "40%";
          CPUWeight = "150";
        };
      };
      environment.etc."yggdrasil.conf".text = if config.pro-peer.yggdrasilConfigPath == null then ''{ Peers: [] }'' else null;
    })

    (lib.mkIf config.pro-peer.enableWireguardHelper {
      environment.systemPackages = with pkgs; [ wireguard-tools ];
      systemd.services."pro-peer-wg-quick" = {
        description = "Bring up WireGuard interface via wg-quick for pro-peer";
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          # systemd does not interpret shell operators unless run via a shell.
          # Use bash -c so the `|| true` is evaluated as intended and the
          # service won't fail the unit when wg-quick returns non-zero.
          ExecStart = builtins.concatStringsSep " " [
            "${pkgs.bash}/bin/bash"
            "-c"
            (let wg = if config.pro-peer.wireguardConfigPath != null then config.pro-peer.wireguardConfigPath else "wg0"; in "/run/current-system/sw/bin/wg-quick up " + wg + " || true")
          ];
          CPUAccounting = "true";
          CPUQuota = "30%";
        };
      };
    })

    (lib.mkIf (config.pro-peer.allowTorHiddenService) {
      environment.etc."pro-peer-tor-note".text = ''Tor hidden service for SSH is enabled. See /var/lib/tor/ssh_hidden_service/hostname'';
    })

    (lib.mkIf (config.pro-peer.allowTorHiddenService) {
      services.tor = {
        enable = true;
        settings = {
          HiddenServiceDir = "/var/lib/tor/ssh_hidden_service";
          HiddenServicePort = "22 127.0.0.1:22";
        };
      };
      systemd.services."pro-peer-tor-key-perms" = {
        description = "Ensure tor hidden service permissions";
        after = [ "tor.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          # Wrap in bash -c so shell operators are recognized by systemd.
          ExecStart = builtins.concatStringsSep " " [
            "${pkgs.bash}/bin/bash"
            "-c"
            "chown -R debian-tor:debian-tor /var/lib/tor/ssh_hidden_service || true && chmod 700 /var/lib/tor/ssh_hidden_service || true"
          ];
          CPUAccounting = "true";
          CPUQuota = "20%";
        };
      };
    })
  ];

}
