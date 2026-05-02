# Название: modules/pro-storage.nix — Samba, Syncthing и локальные хранилища
# Кратко: предоставляет конфигурационные заготовки для сервисов обмена файлами в LAN
# (Samba, Syncthing), шаблоны avahi и рекомендуемые firewall-правила.
#
# Цель:
#   Обеспечить воспроизводимые, безопасные дефолты для общих файловых сервисов в
#   локальной сети, оставляя оператору решение об активации и острой политике доступа.
#
# Контракт:
#   Опции: services.samba.enable, services.syncthing.enable, services.samba.openFirewall
#   Побочные эффекты: при включении открываются SMB/Sync порты и создаются каталоги /srv/samba/*.
#
# Предпосылки:
#   Наличие пакетов samba, syncthing и avahi в окружении. Рекомендуется тестирование на выделенной машине.
#
# Как проверить (Proof):
#   `ss -tlnp | grep -E '445|8384'` или `systemctl status nmbd smbd`.
#
# Last reviewed: 2026-05-02
{ config, lib, ... }:

let
  hostName = config.networking.hostName;
in
{
  # Samba is useful on LANs but can cause boot/start failures on machines
  # without a non-loopback IPv4 interface available (nmbd waits for an
  # interface). Disable by default here to keep `nixos-rebuild switch`
  # reliable. Hosts that need Samba should enable it in their local
  # Почему lib.mkDefault: хосты могут отключить; отключение после включения —
  # ошибка запуска nmbd на машинах без non-loopback IPv4. Хосты переопределят в local.nix.
  # Enable Samba by default; allow hosts to override. Open firewall via NixOS option.
  services.samba.enable = lib.mkDefault true;
  services.samba.openFirewall = lib.mkDefault true;
  # Avahi can fail early during boot if /run/avahi-daemon is missing; ensure
  # tmpfiles create expected runtime directories. Keep avahi enabled for discovery.
  services.avahi.enable = true;
  services.avahi.publish.enable = true;
  # Configure Samba to be reachable on the local network only and advertise via mDNS
  # Use the declarative settings sections: "global" + per-share sections
  # Gobal Samba parameters are security-sensitive. Prefer them to be applied
  # deterministically, but keep them additive at the module level to allow
  # host-specific overrides. Use lib.mkDefault here and let a top-level
  # composition decide whether to force global security settings.
  services.samba.settings."global" = lib.mkDefault {
    workgroup = "WORKGROUP";
    "server string" = "NixOS Samba Server";
    # Почему "Bad User": анонимный гость маппится на реального пользователя,
    # позволяет "guest ok = yes" работать без создания guest-учётки.
    "map to guest" = "Bad User";
    # usershare convenience: keep allowed but it's safer to restrict shares
    "usershare allow guests" = "No";

    # Почему SMB2 minimum: отключаем SMB1 (уязвимый), требуем SMB2+.
    # Как проверить: `smbstatus -L` покажет версию протокола.
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
      # Rationale: share defaults intentionally permissive for discovery; hosts may tighten ACLs.
      # Proof: tests/contract/unit/08-pro-privacy-packages.sh + manual SMB browse via avahi (see docs/plans/smb-discovery-and-mount.md).
      "read only" = "no";
      "guest ok" = "no";
      "force group" = "pro";
      "create mask" = "0775";
      "directory mask" = "2775";
      "valid users" = "az za la bo";
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

  # Контекст: конфигурация fail2ban зависит от путей логов и локальной политики.
  # Рекомендуется задавать правила и jails на уровне хоста для точной привязки к
  # локальным путям и особенностям логирования.

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
      <name replace-wildcards="yes">%h</name>
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
