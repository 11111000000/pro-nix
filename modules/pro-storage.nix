{ config, ... }:

let
  hostName = config.networking.hostName;
in
{
  services.samba.enable = true;
  services.samba.openFirewall = true;
  services.avahi.enable = true;
  services.avahi.publish.enable = true;
  services.samba.extraConfig = ''
    [global]
      workgroup = WORKGROUP
      server string = NixOS Samba Server
      map to guest = Bad User
      usershare allow guests = Yes
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

  systemd.tmpfiles.rules = [
    "d /srv/samba/${hostName} 2775 root pro - -"
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
}
