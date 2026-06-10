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
# Last reviewed: 2026-05-03
{ config, lib, ... }:

let
  hostName = config.networking.hostName;
in
{
  # Samba useful in LAN, but nmbd can hang on startup if there's no ready
  # non-loopback IPv4 interface. So common module just describes
  # configuration, host enables service explicitly in host/local config.
  services.samba.enable = lib.mkDefault true;
  services.samba.openFirewall = lib.mkDefault true;
  # Avahi can fail early during boot if /run/avahi-daemon is missing; ensure
  # tmpfiles create expected runtime directories. Keep avahi enabled for discovery.
  services.avahi.enable = lib.mkDefault true;
  services.avahi.publish.enable = lib.mkDefault true;
  services.avahi.allowInterfaces = lib.mkDefault [ "eth*" "wlan*" "en*" "wlp*" ];
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
    "d /srv/syncthing 2775 root pro - -"
    "d /srv/syncthing/share 2775 root pro - -"
    # /var/lib/pro-samba holds the one-time-setup marker so we never
    # re-prompt for Samba passwords on subsequent switches.
    "d /var/lib/pro-samba 0755 root root - -"
    # NFS runtime paths (opt-in NFS server creates /srv/nfs)
    "d /srv/nfs 2775 root pro - -"
  ];

  # One-time Samba passdb bootstrap. Runs at activation of the local-fs
  # target so /etc/samba and `smbpasswd` are available. Idempotent: skips
  # any user already in the passdb (pdbedit -L).
  #
  # Password sourcing priority (highest first):
  #   1. PRO_SAMBA_PASS_<USER> env var (set in local.nix secrets)
  #   2. /etc/samba/creds.d/passwd-file (mode 600, USER:PASSWORD lines)
  #   3. interactive prompt on a tty
  #
  # If none of the above work, that user is reported in the unit's stdout
  # and the service exits 0 anyway — the operator must run
  # `ops-pro-samba-setup-users` manually later.
  environment.etc."pro/ops-pro-samba-setup-users.sh".source = ../scripts/ops-pro-samba-setup-users.sh;
  environment.etc."pro/ops-pro-samba-setup-users.sh".mode = "0755";
  systemd.services."pro-samba-setup-users" = {
    description = "Populate Samba passdb with pro-nix Unix users (one-shot)";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-tmpfiles-setup.service" ];
    before = [ "smbd.service" ];
    # Run AFTER smbd first time so the service is at least running, but the
    # script is idempotent and can run again on next switch.
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = "yes";
      ExecStart = "/etc/pro/ops-pro-samba-setup-users.sh";
      # Marker file prevents re-prompting on every switch.
      SuccessExitStatus = "0 1";
    };
  };

  services.syncthing = {
    enable = lib.mkDefault true;
    guiAddress = "127.0.0.1:8384";
    openDefaultPorts = false;

    # Declarative shared folder at /srv/syncthing/share — replaces the
    # default ~/Sync that Syncthing would create under dataDir.
    # All members of the `pro` group have read-write access (2775 setgid).
    settings.folders."share" = {
      path = "/srv/syncthing/share";
      id = "share";
      label = "Shared Folder";
    };
  };

  # Permit the syncthing daemon to write to /srv/syncthing/share
  # (owned by root:pro via tmpfiles).
  users.users.syncthing.extraGroups = [ "pro" ];

  users.groups.pro.members = lib.mkDefault [ "az" "za" "la" "bo" ];

  # Контекст: конфигурация fail2ban зависит от путей логов и локальной политики.
  # Рекомендуется задавать правила и jails на уровне хоста для точной привязки к
  # локальным путям и особенностям логирования.

  networking.firewall = {
    # Keep application ports open (exposed generally). SMB ports are opened by
    # services.samba.openFirewall; keep other app ports here.
    allowedTCPPorts = [ 22000 8384 ];
    allowedUDPPorts = [
      21027       # Syncthing discovery
      137 138     # NetBIOS name/datagram service
      5353        # mDNS (Avahi) — без этого хосты не находят друг друга по hostname.local
    ];
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

  # ── NFS (opt-in) ──────────────────────────────────────────────────────────
  # NFSv4 server экспортирует /srv/nfs в LAN. По умолчанию ВЫКЛЮЧЕН —
  # включается на desktop-хосте через `services.nfs.server.enable = true`
  # (или `pro.nfs.server.enable = true` если импортирован opt-in модуль).
  # Клиенты монтируют desktop:/srv/nfs в /mnt/desktop-nfs через
  # `services.nfs.client.enable = true` + `fileSystems`.
  #
  # Почему NFSv4 + sec=sys: в маленькой доверенной LAN (pro-nix 4 хоста) —
  # самое простое. UID маппятся 1:1, потому что NixOS даёт одинаковые UID
  # для az/za/la/bo на всех хостах (см. pro-users.nix).
  #
  # Почему НЕ включаем по умолчанию: NFS-server слушает на 2049/tcp+udp
  # и открывает потенциальную attack surface; пусть хост, который реально
  # хочет быть файлосервером, opt-in'ит явно.
  # (tmpfiles rule for /srv/nfs moved into the main tmpfiles list above)

  # ── Avahi: публикация _nfs._tcp для клиентов ─────────────────────────────
  # Клиенты (gvfs, KDE, macOS Finder) находят NFS-шару по .local имени хоста.
  environment.etc."avahi/services/nfs.service".text = ''
    <?xml version="1.0" standalone='no'?>
    <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
    <service-group>
      <name replace-wildcards="yes">%h NFS</name>
      <service>
        <type>_nfs._tcp</type>
        <port>2049</port>
      </service>
    </service-group>
  '';

  # Avahi is enabled above; Samba is configured to bind to the local LAN subnet
  # and will be discoverable on the local Wi‑Fi network. If additional mDNS
  # publication is needed, we can add service definition files under
  # /etc/avahi/services/ via NixOS `environment.etc`.
}
