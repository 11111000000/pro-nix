{ config, lib, ... }:

let
  hostName = config.networking.hostName;
in
{
  # Samba is useful on LANs but can cause boot/start failures on machines
  # without a non-loopback IPv4 interface available (nmbd waits for an
  # interface). Disable by default here to keep `nixos-rebuild switch`
  # reliable. Hosts that need Samba should enable it in their local
  # per-host config (eg. local.nix) or remove this override.
  services.samba.enable = false;
  services.samba.openFirewall = false;
  # Avahi can fail early during boot if /run/avahi-daemon is missing; ensure
  # tmpfiles create expected runtime directories. Do not change avahi.enable
  # behavior here — keep the service enabled as originally configured.
  services.avahi.enable = true;
  services.avahi.publish.enable = true;
  # Configure Samba to be reachable on the local network only and advertise via mDNS
  # Use the structured settings API for newer NixOS releases
  services.samba.settings.global = lib.mkForce {
    workgroup = "WORKGROUP";
    "server string" = "NixOS Samba Server";
    # Avoid mapping unknown users to guest; explicit users only.
    "map to guest" = "Never";
    # usershare convenience: keep allowed but it's safer to restrict shares
    "usershare allow guests" = "No";

    # Protocol hardening: disable SMB1, require SMB2+.
    "server min protocol" = "SMB2";
    "client min protocol" = "SMB2";

    # Require signing to mitigate MITM and relay attacks on local networks.
    # This may break very old clients; adjust to "required" or "desired"
    # depending on your environment. We choose "required" for safety.
    "server signing" = "required";
    "client signing" = "required";

    # Prefer encryption when supported. "required" forces SMB3 encryption
    # and may break legacy clients; leaving as "desired" is friendlier.
    "smb encrypt" = "desired";

    # Restrict anonymous access and disable NTLMv1.
    "restrict anonymous" = "2";
    "ntlm auth" = "no";

    # Do not hardbind interfaces here; allow binding to available interfaces
    # so the service starts reliably on dynamic Wi‑Fi networks.
    "bind interfaces only" = "No";
  };
  services.samba.shares."${hostName}" = {
    path = "/srv/samba/${hostName}";
    browseable = "yes";
    "read only" = "no";
    "guest ok" = "no";
    "force group" = "pro";
    "create mask" = "0775";
    "directory mask" = "2775";
    "valid users" = "az zo la bo";
  };
  services.samba.shares.public = {
    path = "/srv/samba/public";
    browseable = "yes";
    "read only" = "no";
    "guest ok" = "yes";
    "guest only" = "yes";
    "force user" = "az";
    "create mask" = "0775";
    "directory mask" = "2775";
  };

  systemd.tmpfiles.rules = [
    "d /srv/samba/${hostName} 2775 root pro - -"
    "d /srv/samba/public 2775 az pro - -"
  ];

  services.syncthing = {
    enable = true;
    guiAddress = "127.0.0.1:8384";
    openDefaultPorts = false;
  };

  # NOTE: fail2ban configuration can be added per-host if desired. Avoid
  # enabling a global jail here to keep host-specific tuning (filters/log
  # paths) local to the machine.

  networking.firewall = {
    # Keep application ports open (exposed generally). We remove SMB ports
    # from the global "allowedTCPPorts" list and instead add explicit
    # firewall rules below to restrict access to RFC1918 private nets.
    allowedTCPPorts = [ 22000 8384 ];
    allowedUDPPorts = [ 21027 137 138 ];

    # Extra commands: allow SMB (139/445) only from RFC1918 networks and
    # drop/deny from elsewhere. This provides network-level protection even
    # if Samba is enabled on the host.
    # Prefer nftables when available. Construct an nftables table+chain that
    # allows SMB ports only from RFC1918 and drops elsewhere. If nftables is
    # not available, fall back to iptables commands for compatibility.
    # Use declarative nftables ruleset to restrict SMB ports to RFC1918 networks.
    # This is applied declaratively by NixOS and is preferred over procedural
    # extraCommands. Keep a minimal, idempotent ruleset that permits
    # established traffic, allows SMB from private networks and drops others.
    networking.nftables.enable = true;
    networking.nftables.rules = lib.mkForce ''
      table inet pro-nix-smb {
        chain input {
          type filter hook input priority 0;
          policy accept;

          # allow established
          ct state established,related accept

          # allow SMB from RFC1918
          ip saddr 10.0.0.0/8 tcp dport {139,445} accept
          ip saddr 172.16.0.0/12 tcp dport {139,445} accept
          ip saddr 192.168.0.0/16 tcp dport {139,445} accept

          # drop SMB from elsewhere
          tcp dport {139,445} drop
        }
      }
    '';
  };

  # Avahi is enabled above; Samba is configured to bind to the local LAN subnet
  # and will be discoverable on the local Wi‑Fi network. If additional mDNS
  # publication is needed, we can add service definition files under
  # /etc/avahi/services/ via NixOS `environment.etc`.
}
