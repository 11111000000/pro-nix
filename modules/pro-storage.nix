# Название: modules/pro-storage.nix — Samba, Syncthing и локальные хранилища
# Кратко: предоставляет конфигурационные заготовки для сервисов обмена файлами в LAN
# (Samba, Syncthing), шаблоны avahi и рекомендуемые firewall-правила.
#
# Цель:
#   Обеспечить воспроизводимые, безопасные дефолты для общих файловых сервисов в
#   локальной сети, оставляя оператору решение об активации и острой политике доступа.
#
# Контракт:
#   Опции:
#     pro.samba.enable              — bool (default: авто-on для хостов с ролью `nfs`,
#                                    иначе false). Включает services.samba + smbpasswd.
#     pro.samba.shareNfsPath        — bool (default true). Публиковать /srv/nfs
#                                    через Samba как гостевую RW-шару с force group=pro.
#     services.syncthing.enable     — по-прежнему lib.mkDefault true.
#   Побочные эффекты: при включении открываются SMB/Sync порты и создаются каталоги /srv/samba/*.
#
# Предпосылки:
#   Наличие пакетов samba, syncthing и avahi в окружении. Рекомендуется тестирование на выделенной машине.
#
# Как проверить (Proof):
#   `ss -tlnp | grep -E '445|8384'` или `systemctl status nmbd smbd`.
#
# Last reviewed: 2026-06-18
{ config, lib, pkgs, ... }:

let
  hostName = config.networking.hostName;
  cfg = config.pro.samba;
  # Авто-on для хостов с ролью `nfs` (по аналогии с pro.network.allowSubnetRouter для lan-gw).
  # В pro.hosts.<name>.roles роль `nfs` означает: "этот хост экспортирует NFS-шару".
  # Логично, что тот же хост публикует её и через SMB — для клиентов, у которых
  # нет NFS (Android, Windows). Сам хост (desktop) может включить явно через
  # `pro.samba.enable = true` для override.
  isNfsHost = builtins.elem "nfs" (config.pro.hosts.${hostName}.roles or [ ]);
  cfgEnable = cfg.enable or (isNfsHost);
in
{
  # Опции модуля — отдельным блоком. NixOS требует, чтобы все config-атрибуты
  # (services, systemd, users, environment, networking) шли ВНУТРИ одного
  # атрибутного литерала, а не на верхнем уровне рядом с options.
  options.pro.samba = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = isNfsHost;
      defaultText = lib.literalExpression "true for hosts with role \"nfs\" in pro.hosts, else false";
      description = ''
        Run Samba (smbd/nmbd) on this host. Defaults to true for hosts whose
        pro.hosts.<name>.roles contains "nfs" (i.e. desktop) — those hosts
        export /srv/nfs via NFS and also publish it as a guest SMB share.
        Set explicitly to true on a non-nfs host or false on desktop if you
        want to opt out.
      '';
    };
    shareNfsPath = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Publish /srv/nfs (the NFS export) as the `nfs` Samba share with
        guest RW, force user=az, force group=pro, create mask=0664,
        directory mask=2775. Combined with the setgid bit on /srv/nfs,
        every LAN client writes as az:pro and the group is preserved on
        new files. Disable if you want Samba shares independent from NFS.
      '';
    };
  };

  config = {
    # Samba: opt-in. nmbd can hang on startup if there's no ready non-loopback
  # IPv4 interface, so we don't auto-enable globally — host with role `nfs`
  # (or explicit pro.samba.enable) decides.
  services.samba.enable = lib.mkIf cfgEnable true;
  services.samba.openFirewall = lib.mkIf cfgEnable true;
  # Avahi can fail early during boot if /run/avahi-daemon is missing; ensure
  # tmpfiles create expected runtime directories. Keep avahi enabled for discovery.
  services.avahi.enable = lib.mkDefault true;
  services.avahi.publish.enable = lib.mkDefault true;
  # allowInterfaces = null (default): avahi слушает все UP-интерфейсы, кроме
  # loopback и point-to-point. Раньше задавали фильтр [ "eth*" "wlan*" "en*" "wlp*" ],
  # но на cf19 (интерфейс wlp9s0) avahi-daemon 0.8 молча не присоединялся к
  # mDNS-группе 224.0.0.251 при заданном allow-interfaces, и SMB-discovery
  # не работал. Глобальное правило pro-nix: не задавать allowInterfaces.
  # NB: включаются ВСЕ интерфейсы (в т.ч. wwan0, tailscale0, docker0), что
  # для домашней LAN приемлемо. Если на каком-то хосте нужна фильтрация —
  # задать опцию host-local c lib.mkForce.
  # Configure Samba to be reachable on the local network only and advertise via mDNS
  # Use the declarative settings sections: "global" + per-share sections
  # Gobal Samba parameters are security-sensitive. Prefer them to be applied
  # deterministically, but keep them additive at the module level to allow
  # host-specific overrides. Use lib.mkDefault here and let a top-level
  # composition decide whether to force global security settings.
  services.samba.settings."global" = lib.mkIf cfgEnable (lib.mkDefault {
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
  });
  # Define Samba shares as sections under services.samba.settings
  services.samba.settings."${hostName}" = lib.mkIf cfgEnable {
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

  services.samba.settings.public = lib.mkIf cfgEnable {
      path = "/srv/samba/public";
      browseable = "yes";
      "read only" = "no";
      "guest ok" = "yes";
      "guest only" = "yes";
      "force user" = "az";
      "create mask" = "0775";
      "directory mask" = "2775";
  };

  # ── nfs-share: Samba-зеркало NFS-шары /srv/nfs для клиентов без NFS ──
  # Это та же директория, что экспортируется pro-nfs.nix через NFSv4. Любой
  # LAN-клиент (Android, Windows, Linux без nfs-utils) может зайти гостем
  # и писать; `force user = az` + `force group = pro` гарантируют, что
  # файлы приходят как az:pro и совместимы с правами NFS-клиентов.
  #
  # Почему `guest ok = yes` + `map to guest = Bad User` (см. global выше):
  # Android-галереи и Windows-проводник логинятся анонимно; "Bad User"
  # маппит unknown-user на guest-аккаунт, дальше `guest only = yes` принуждает
  # исполнять все операции под `force user`. Без guest-only любой
  # невалидный Unix-юзер (например, nobody) мог бы попытаться писать
  # под своим UID — мы этого не хотим.
  #
  # NB: `shareNfsPath = false` отключает только ЭТУ шару; Samba-сервер
  # остаётся работать (нужен для `public` и `${hostName}`). Чтобы
  # выключить Samba целиком — `pro.samba.enable = false`.
  # Двойное условие (cfgEnable && cfg.shareNfsPath) — без Samba-сервера
  # шарить /srv/nfs через SMB бессмысленно.
  services.samba.settings.nfs = lib.mkIf (cfgEnable && cfg.shareNfsPath) {
    path = "/srv/nfs";
    browseable = "yes";
    "read only" = "no";
    "guest ok" = "yes";
    "guest only" = "yes";
    "force user" = "az";
    "force group" = "pro";
    "create mask" = "0664";
    "directory mask" = "2775";
    # Скрываем share от browse-list на чужих vlan'ах (на практике
    # hosts allow/deny в global уже фильтрует, но явное ограничение
    # защищает от случайного export'а через VPN/Tailscale в чужой LAN).
    "hosts allow" = "127.0.0.1 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16";
    "hosts deny" = "0.0.0.0/0";
  };

  systemd.tmpfiles.rules = [
    # Samba-каталоги создаём только на хостах, где Samba реально работает;
    # на остальных tmpfiles-правило не нужно и может сбить с толку (каталог
    # создаётся и пустует).
    (lib.mkIf cfgEnable "d /srv/samba/${hostName} 2775 root pro - -")
    (lib.mkIf cfgEnable "d /srv/samba/public 2775 az pro - -")
    (lib.mkIf cfgEnable ''
      # /var/lib/pro-samba holds the one-time-setup marker so we never
      # re-prompt for Samba passwords on subsequent switches.
      d /var/lib/pro-samba 0755 root root - -
    '')
    "d /srv/syncthing 2775 root pro - -"
    "d /srv/syncthing/share 2775 root pro - -"
    # NFS runtime paths (opt-in NFS server creates /srv/nfs). Создаём
    # ВСЕГДА — даже на хостах без Samba/NFS-сервера, потому что /srv/nfs
    # используется ещё и как SMB-share на desktop'е (через services.samba).
    # На клиентах каталог создаётся, но Samba/NFS не стартуют — это просто
    # страховка, что на desktop'е после `just switch` он точно существует
    # с правильными правами.
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
  environment.etc."pro/ops-pro-samba-setup-users.sh" = lib.mkIf cfgEnable {
    source = ../scripts/ops-pro-samba-setup-users.sh;
    mode = "0755";
  };
  systemd.services."pro-samba-setup-users" = lib.mkIf cfgEnable {
    description = "Populate Samba passdb with pro-nix Unix users (one-shot)";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-tmpfiles-setup.service" ];
    before = [ "smbd.service" ];
    # Run AFTER smbd first time so the service is at least running, but the
    # script is idempotent and can run again on next switch.
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = "yes";
      # Wrap ExecStart in `env -i ...` so the script sees the canonical
      # NixOS system PATH (including samba's smbpasswd/pdbedit) and not
      # the truncated one-shot PATH that systemd defaults to. The
      # service's effective PATH is otherwise only coreutils/findutils/
      # gnugrep/gnused/systemd — no samba, no awk, no /usr/bin.
      #
      # NB: `/run/current-system/sw/bin` is the per-system profile that
      # symlinks every package enabled by `services.samba.*` and any
      # other module in this configuration. It is the same path that
      # user shells see, so this is the most predictable choice.
      ExecStart = "/usr/bin/env -i PATH=/run/current-system/sw/bin:/run/current-system/sw/sbin:/run/current-system/sw/lib/kde4/libexec:/bin:/sbin LOCALE_ARCHIVE=${pkgs.glibcLocales}/lib/locale/locale-archive /etc/pro/ops-pro-samba-setup-users.sh";
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

  # Override systemd umask for the syncthing service: default 0022 makes new
  # files land as 0644 (syncthing:pro) so group `pro` members get read-only.
  # With 0002, files are 0664 and directories 0775 — paired with the setgid
  # bit on /srv/syncthing/share (tmpfiles rule above), every pro member can
  # read AND write, and new files inherit the `pro` group automatically.
  systemd.services.syncthing.serviceConfig.UMask = "0002";

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
  };
}
