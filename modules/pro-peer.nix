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

  config = lib.mkIf (config.pro-peer.enable or true) {
    # Avahi for mDNS host discovery in LAN
    services.avahi = {
      enable = true;
      publish = {
        # advertise ssh services via DNS-SD
        _ssh._tcp = {
          port = 22;
        };
      };
    };

    # SSH hardening defaults for pro-nix peers
    services.openssh = {
      enable = true;
      permitRootLogin = "no";
      passwordAuthentication = false; # require keys
      challengeResponseAuthentication = false;
      # use a small set of safe ciphers (let nixpkgs choose sensible defaults)
      # Extra options can be added by users via services.openssh.extraConfig
    };

    # A small helper: create directory for pro-peer pubkeys if admin wants to populate it
    users.users.root.openssh.authorizedKeys.keysFile = 
      lib.mkForce "/var/lib/pro-peer/authorized_keys";

    systemd.tmpfiles.rules = [
      # ensure directory for collected authorized keys exists
      "d /var/lib/pro-peer 0700 root root -"
    ];
  };

  # key sync service & timer
  config = lib.mkIf config.pro-peer.enableKeySync {
    # install helper script from repo to /usr/local/bin
    environment.systemPackages = with pkgs; [ gnupg ];
    environment.etc."pro-peer-sync-keys.sh".source = ./scripts/pro-peer-sync-keys.sh;
    environment.etc."pro-peer-sync-keys.sh".mode = "0755";

    systemd.services."pro-peer-sync-keys" = {
      description = "Pro‑peer: sync authorized_keys from encrypted file";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = 
          ''/etc/pro-peer-sync-keys.sh --input ${config.pro-peer.keysGpgPath} --out /var/lib/pro-peer/authorized_keys'';
      };
    };

    systemd.timers."pro-peer-sync-keys.timer" = {
      description = "Periodic pro-peer key sync";
      timerConfig = {
        OnUnitActiveSec = config.pro-peer.keySyncInterval;
      };
      wantedBy = [ "timers.target" ];
    };
  };

  # Tor hidden service backup helper
  config = lib.mkIf (config.pro-peer.allowTorHiddenService and config.pro-peer.torBackupRecipient != null) {
    environment.systemPackages = with pkgs; [ gnupg tar ];
    environment.etc."pro-peer-backup-hiddenservice.sh".source = ./scripts/backup-hiddenservice.sh;
    environment.etc."pro-peer-backup-hiddenservice.sh".mode = "0755";

    systemd.services."pro-peer-backup-hiddenservice" = {
      description = "Backup tor hidden service key encrypted to recipient";
      after = [ "tor.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = ''/etc/pro-peer-backup-hiddenservice.sh --hidden-dir /var/lib/tor/ssh_hidden_service --recipient "${config.pro-peer.torBackupRecipient}" --out-dir /var/lib/pro-peer '';
      };
    };
  };

  # Yggdrasil service helper
  config = lib.mkIf config.pro-peer.enableYggdrasil {
    environment.systemPackages = with pkgs; [ yggdrasil ];
    systemd.services.yggdrasil = {
      description = "Yggdrasil mesh daemon (pro-peer)";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = ''${pkgs.yggdrasil}/bin/yggdrasil -useconffile ${config.pro-peer.yggdrasilConfigPath or "/etc/yggdrasil.conf"}'';
        Restart = "on-failure";
      };
    };
    # Ensure default config exists if none provided
    environment.etc."yggdrasil.conf".source = lib.mkIf (config.pro-peer.yggdrasilConfigPath == null) ''
{
  Peers: []
}
'' '';
  };

  # WireGuard helper: bring up wg-quick if config provided
  config = lib.mkIf config.pro-peer.enableWireguardHelper {
    environment.systemPackages = with pkgs; [ wireguard-tools ];
    systemd.services."pro-peer-wg-quick" = {
      description = "Bring up WireGuard interface via wg-quick for pro-peer";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = ''/run/current-system/sw/bin/wg-quick up ${config.pro-peer.wireguardConfigPath or "wg0"} || true'';
      };
    };
  };

  # Optional tor hidden service example. Disabled by default.
  # If you set pro-peer.allowTorHiddenService = true in your host config,
  # the module will enable tor and create a HiddenService for SSH.
  environment.etc."pro-peer-tor-note".text = lib.mkIf (config.pro-peer.allowTorHiddenService) ''
    Tor hidden service for SSH is enabled. See /var/lib/tor/ssh_hidden_service/hostname
  '' '';

  config = lib.mkIf (config.pro-peer.allowTorHiddenService) (let
    torDir = "/var/lib/tor/ssh_hidden_service";
  in {
    services.tor = {
      enable = true;
      extraConfig = ''
HiddenServiceDir ${torDir}
HiddenServicePort 22 127.0.0.1:22
'';
    };
    systemd.services."pro-peer-tor-key-perms" = {
      description = "Ensure tor hidden service permissions";
      after = [ "tor.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = ''
          chown -R debian-tor:debian-tor ${torDir} || true
          chmod 700 ${torDir} || true
        '';
      };
    };
  }) else {};

}
