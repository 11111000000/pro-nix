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
        publish = {
          enable = true; # advertise the host via mDNS
        };
      };
      # Provide an Avahi service file advertising SSH over mDNS so non-Linux
      # clients (macOS, iOS, Android apps with Bonjour support) can discover
      # the host and connect to port 22.
      environment.etc."avahi/services/ssh.service".text = ''
        <?xml version="1.0" standalone='no'?>
        <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
        <service-group>
          <name replace-wildcards="yes">%h</name>
          <service>
            <type>_ssh._tcp</type>
            <port>22</port>
          </service>
        </service-group>
      '';

      # SSH hardening defaults for pro-nix peers
       services.openssh = {
         enable = true;
         settings = {
           PermitRootLogin = "no";
           PasswordAuthentication = false;
           KbdInteractiveAuthentication = false;
           # Read authorized keys from runtime-managed file first, then per-user files
           AuthorizedKeysFile = "/var/lib/pro-peer/authorized_keys %h/.ssh/authorized_keys";
         };
       };

      # Ensure directory for runtime-managed authorized_keys exists with
      # secure permissions and provide a visible placeholder so state is
      # inspectable. We avoid pointing Nix's sshd module at a runtime file
      # (which could be unavailable during evaluation) but provide tmpfiles
      # and an on-disk placeholder for operators.
      # Add tmpfiles rules for runtime-managed pro-peer state. Do not force
      # the entire `systemd.tmpfiles.rules` option here so other modules
      # (and package-provided defaults like avahi) can append their rules.
      systemd.tmpfiles.rules = [
        "d /var/lib/pro-peer 0700 root root -"
        "f /var/lib/pro-peer/authorized_keys 0600 root root -"
        # Ensure Avahi's runtime directory exists early so the daemon doesn't
        # fail when systemd starts it before tmpfiles are applied by other
        # packages. Ownership matches the avahi package expectations.
        "d /run/avahi-daemon 0755 avahi avahi -"
      ];

      # Allow mDNS (UDP/5353) in the firewall so hosts can discover each other
      # via Avahi/mDNS on the LAN. Merge with existing allowed UDP ports when
      # present to avoid overwriting other modules' firewall configuration.
      networking.firewall = lib.mkIf true {
        allowedUDPPorts = lib.mkForce (lib.concatLists [ (config.networking.firewall.allowedUDPPorts or []) [ 5353 ] ]);
        # Ensure IPv6 mDNS and IPv4 multicast for discovery are permitted. Use
        # extraCommands for idempotent rules that allow multicast traffic used
        # by Avahi (224.0.0.251 and ff02::fb) in addition to UDP/5353.
        extraCommands = lib.mkForce ''
          # Allow IPv4 mDNS UDP port 5353 (multicast 224.0.0.251)
          iptables -C INPUT -p udp --dport 5353 -d 224.0.0.251 -j ACCEPT 2>/dev/null || iptables -I INPUT -p udp --dport 5353 -d 224.0.0.251 -j ACCEPT || true
          # Allow IPv6 mDNS (multicast ff02::fb)
          ip6tables -C INPUT -p udp --dport 5353 -d ff02::fb -j ACCEPT 2>/dev/null || ip6tables -I INPUT -p udp --dport 5353 -d ff02::fb -j ACCEPT || true
        '';
      };

      environment.etc."pro-peer/authorized_keys".text = "# Managed at runtime by pro-peer-sync-keys\n";

      # Keep sshd's Nix config from reading arbitrary files at evaluation
      # time by forcing an empty authorizedKeys declaration. The runtime
      # service writes to /var/lib/pro-peer/authorized_keys which SSH will
      # read at service start.
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
      # Install a small wrapper script that normalizes wg-quick behavior so
      # the systemd unit can remain simple and not embed shell operators.
      environment.etc."pro-peer-wg-quick-wrapper".source = ./scripts/pro-peer-wg-quick-wrapper.sh;
      environment.etc."pro-peer-wg-quick-wrapper".mode = "0755";

      systemd.services."pro-peer-wg-quick" = {
        description = "Bring up WireGuard interface via wg-quick for pro-peer";
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = ''/etc/pro-peer-wg-quick-wrapper ${if config.pro-peer.wireguardConfigPath != null then config.pro-peer.wireguardConfigPath else "wg0"}'';
          # The wrapper normalizes exit codes and always returns 0.
          RemainAfterExit = "yes";
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

      # Ensure the hidden service directory exists with correct ownership and
      # permissions using systemd-tmpfiles rules. This is declarative and will
      # be applied early in boot, avoiding a oneshot service which embeds shell
      # logic.
      # If Tor hidden service is enabled, add a tmpfiles rule to ensure the
      # directory exists with correct ownership. Again, append to the global
      # rules list rather than forcing it.
      systemd.tmpfiles.rules = lib.mkIf config.pro-peer.allowTorHiddenService [
        "d /var/lib/tor/ssh_hidden_service 0700 debian-tor debian-tor -"
      ];
    })
  ];

}
