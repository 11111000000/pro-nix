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
    (lib.mkIf (config.pro-peer.enable || true) {
      # Avahi for mDNS host discovery in LAN
      services.avahi = {
        enable = true;
      };

      # SSH hardening defaults for pro-nix peers
      services.openssh = {
        enable = true;
        permitRootLogin = "no";
        passwordAuthentication = false;
        challengeResponseAuthentication = false;
      };

      # A small helper: create directory for pro-peer pubkeys if admin wants to populate it
      users.users.root.openssh.authorizedKeys.keyFiles = lib.mkForce [ "/var/lib/pro-peer/authorized_keys" ];

      systemd.tmpfiles.rules = [ "d /var/lib/pro-peer 0700 root root -" ];
    })

    (lib.mkIf config.pro-peer.enableKeySync {
      environment.systemPackages = with pkgs; [ gnupg ];
      environment.etc."pro-peer-sync-keys.sh".source = ./scripts/pro-peer-sync-keys.sh;
      environment.etc."pro-peer-sync-keys.sh".mode = "0755";

      systemd.services."pro-peer-sync-keys" = {
        description = "Pro‑peer: sync authorized_keys from encrypted file";
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = builtins.concatStringsSep " " [ "/etc/pro-peer-sync-keys.sh" "--input" config.pro-peer.keysGpgPath "--out" "/var/lib/pro-peer/authorized_keys" ];
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
      environment.etc."pro-peer-backup-hiddenservice.sh".source = ./scripts/backup-hiddenservice.sh;
      environment.etc."pro-peer-backup-hiddenservice.sh".mode = "0755";

      systemd.services."pro-peer-backup-hiddenservice" = {
        description = "Backup tor hidden service key encrypted to recipient";
        after = [ "tor.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = builtins.concatStringsSep " " [ "/etc/pro-peer-backup-hiddenservice.sh" "--hidden-dir" "/var/lib/tor/ssh_hidden_service" "--recipient" config.pro-peer.torBackupRecipient "--out-dir" "/var/lib/pro-peer" ];
        };
      };
    })

    (lib.mkIf config.pro-peer.enableYggdrasil {
      environment.systemPackages = with pkgs; [ yggdrasil ];
      systemd.services.yggdrasil = {
        description = "Yggdrasil mesh daemon (pro-peer)";
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          ExecStart = builtins.concatStringsSep " " [ (builtins.toString pkgs.yggdrasil + "/bin/yggdrasil") "-useconffile" (if config.pro-peer.yggdrasilConfigPath != null then config.pro-peer.yggdrasilConfigPath else "/etc/yggdrasil.conf") ];
          Restart = "on-failure";
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
          ExecStart = (let wg = if config.pro-peer.wireguardConfigPath != null then config.pro-peer.wireguardConfigPath else "wg0"; in builtins.concatStringsSep " " [ "/run/current-system/sw/bin/wg-quick" "up" wg "||" "true" ]);
        };
      };
    })

    (lib.mkIf (config.pro-peer.allowTorHiddenService) {
      environment.etc."pro-peer-tor-note".text = ''Tor hidden service for SSH is enabled. See /var/lib/tor/ssh_hidden_service/hostname'';
    })

    (lib.mkIf (config.pro-peer.allowTorHiddenService) {
      services.tor = {
        enable = true;
        extraConfig = builtins.concatStringsSep "\n" [ "HiddenServiceDir /var/lib/tor/ssh_hidden_service" "HiddenServicePort 22 127.0.0.1:22" ];
      };
      systemd.services."pro-peer-tor-key-perms" = {
        description = "Ensure tor hidden service permissions";
        after = [ "tor.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = builtins.concatStringsSep " && " [ "chown -R debian-tor:debian-tor /var/lib/tor/ssh_hidden_service || true" "chmod 700 /var/lib/tor/ssh_hidden_service || true" ];
        };
      };
    })
  ];

}
