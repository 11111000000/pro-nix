{ config, pkgs, lib, ... }:

let
  cfg = {};
in

{
  options = {
    pro-peer = {
      enable = lib.mkEnableOption "Enable pro peer discovery defaults (Avahi + SSH hardening)";
      allowTorHiddenService = lib.mkEnableOption "Enable tor hidden-service example for SSH (off by default)";
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
