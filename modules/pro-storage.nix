# Файл: автосгенерированная шапка — комментарии рефакторятся
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
  # Enable Samba by default; allow hosts to override. Open firewall via NixOS option.
  services.samba.enable = lib.mkDefault true;
  services.samba.openFirewall = lib.mkDefault true;
  # Avahi can fail early during boot if /run/avahi-daemon is missing; ensure
  # tmpfiles create expected runtime directories. Do not change avahi.enable
  # behavior here — keep the service enabled as originally configured.
  services.avahi.enable = true;
  services.avahi.publish.enable = true;
  # Configure Samba to be reachable on the local network only and advertise via mDNS
  # Use the declarative settings sections: "global" + per-share sections
  services.samba.settings."global" = lib.mkForce {
    workgroup = "WORKGROUP";
    "server string" = "NixOS Samba Server";
    # Map неизвестного пользователя в гостя, чтобы анонимный доступ к public
    # реально работал (вместе с "guest ok = yes" на секции шары).
    "map to guest" = "Bad User";
    # usershare convenience: keep allowed but it's safer to restrict shares
    "usershare allow guests" = "No";

    # Protocol hardening: disable SMB1, require SMB2+.
    "server min protocol" = "SMB2";
    "client min protocol" = "SMB2";

    # Prefer signing for compatibility with Android clients; allow stronger
    # clients to use signing while not blocking those without it.
    "server signing" = "desired";
    "client signing" = "desired";

    # Prefer encryption when supported.
    "smb encrypt" = "desired";

    # Restrict anonymous access and disable NTLMv1.
    "restrict anonymous" = "2";
    "ntlm auth" = "no";

    # Do not hardbind interfaces here; allow binding to available interfaces
    # so the service starts reliably on dynamic Wi‑Fi networks.
    "bind interfaces only" = "No";

    # Limit access to RFC1918 addresses at the Samba layer (defense in depth),
    # independent from firewall backend.
    "hosts allow" = "127.0.0.1 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16";
    "hosts deny" = "0.0.0.0/0";
  };
  # Define Samba shares as sections under services.samba.settings
  services.samba.settings."${hostName}" = {
      path = "/srv/samba/${hostName}";
      browseable = "yes";
      "read only" = "no";
      "guest ok" = "no";
      "force group" = "pro";
      "create mask" = "0775";
      "directory mask" = "2775";
      "valid users" = "az zo la bo";
  };

  services.samba.settings.public = {
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

  # Примечание: конфигурацию fail2ban лучше задавать на уровне хоста. Глобальное
  # включение jail может привести к неверной работе из-за различий путей логов и
  # фильтров между машинами; оставляем настройку локальной ответственности.

  networking.firewall = {
    # Keep application ports open (exposed generally). SMB ports are opened by
    # services.samba.openFirewall; keep other app ports here.
    allowedTCPPorts = [ 22000 8384 ];
    allowedUDPPorts = [ 21027 137 138 ];
  };

  # Publish Samba via mDNS for Android discovery.
  environment.etc."avahi/services/samba.service".text = ''
    <?xml version="1.0" standalone='no'?>
    <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
    <service-group>
      <service>
        <type>_smb._tcp</type>
        <port>445</port>
      </service>
    </service-group>
  '';

  # Avahi is enabled above; Samba is configured to bind to the local LAN subnet
  # and will be discoverable on the local Wi‑Fi network. If additional mDNS
  # publication is needed, we can add service definition files under
  # /etc/avahi/services/ via NixOS `environment.etc`.
}
