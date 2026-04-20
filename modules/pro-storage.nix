{ config, lib, ... }:

let
  hostName = config.networking.hostName;
in
{
  services.samba.enable = true;
  services.samba.openFirewall = true;
  services.avahi.enable = true;
  services.avahi.publish.enable = true;
  # Configure Samba to be reachable on the local network only and advertise via mDNS
  services.samba.extraConfig = ''
    [global]
      workgroup = WORKGROUP
      server string = NixOS Samba Server
      map to guest = Bad User
      usershare allow guests = Yes
      # Bind Samba to loopback and the local LAN subnet so it's easy to reach from LAN
      # but not exposed to unrelated external networks. Adjust the CIDR below if your LAN differs.
      interfaces = 127.0.0.1 192.168.181.0/24
      bind interfaces only = Yes
  '';
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

  networking.firewall = {
    allowedTCPPorts = [ 22000 8384 139 445 ];
    allowedUDPPorts = [ 21027 137 138 ];
  };

  # Avahi is enabled above; Samba is configured to bind to the local LAN subnet
  # and will be discoverable on the local Wi‑Fi network. If additional mDNS
  # publication is needed, we can add service definition files under
  # /etc/avahi/services/ via NixOS `environment.etc`.
}
