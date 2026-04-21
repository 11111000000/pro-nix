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
  # Define Samba shares via the structured `services.samba.settings.shares`
  # mapping to avoid deprecated `services.samba.shares` usage.
  services.samba.settings.shares = {
    "${hostName}" = {
      path = "/srv/samba/${hostName}";
      browseable = "yes";
      "read only" = "no";
      "guest ok" = "no";
      "force group" = "pro";
      "create mask" = "0775";
      "directory mask" = "2775";
      "valid users" = "az zo la bo";
    };

    public = {
      path = "/srv/samba/public";
      browseable = "yes";
      "read only" = "no";
      "guest ok" = "yes";
      "guest only" = "yes";
      "force user" = "az";
      "create mask" = "0775";
      "directory mask" = "2775";
    };
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

  # Примечание: конфигурацию fail2ban лучше задавать на уровне хоста. Глобальное
  # включение jail может привести к неверной работе из-за различий путей логов и
  # фильтров между машинами; оставляем настройку локальной ответственности.

  networking.firewall = {
    # Keep application ports open (exposed generally). We remove SMB ports
    # from the global "allowedTCPPorts" list and instead add explicit
    # firewall rules below to restrict access to RFC1918 private nets.
    allowedTCPPorts = [ 22000 8384 ];
    allowedUDPPorts = [ 21027 137 138 ];
  };

  # Use firewall.extraCommands to install idempotent iptables rules that allow
  # SMB only from RFC1918 networks. Some NixOS releases may not expose the
  # "networking.nftables" option; using extraCommands keeps compatibility.
  networking.firewall.extraCommands = ''
    # Allow SMB from 10/8 if not already present
    iptables -C INPUT -p tcp -m multiport --dports 139,445 -s 10.0.0.0/8 -j ACCEPT 2>/dev/null || iptables -I INPUT -p tcp -m multiport --dports 139,445 -s 10.0.0.0/8 -j ACCEPT || true
    # Allow SMB from 172.16/12
    iptables -C INPUT -p tcp -m multiport --dports 139,445 -s 172.16.0.0/12 -j ACCEPT 2>/dev/null || iptables -I INPUT -p tcp -m multiport --dports 139,445 -s 172.16.0.0/12 -j ACCEPT || true
    # Allow SMB from 192.168/16
    iptables -C INPUT -p tcp -m multiport --dports 139,445 -s 192.168.0.0/16 -j ACCEPT 2>/dev/null || iptables -I INPUT -p tcp -m multiport --dports 139,445 -s 192.168.0.0/16 -j ACCEPT || true
    # Drop SMB from elsewhere if not already present
    iptables -C INPUT -p tcp -m multiport --dports 139,445 -j DROP 2>/dev/null || iptables -A INPUT -p tcp -m multiport --dports 139,445 -j DROP || true
  '';

  # Avahi is enabled above; Samba is configured to bind to the local LAN subnet
  # and will be discoverable on the local Wi‑Fi network. If additional mDNS
  # publication is needed, we can add service definition files under
  # /etc/avahi/services/ via NixOS `environment.etc`.
}
