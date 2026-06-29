# Название: modules/pro-nfs.nix — NFSv4 server/client для LAN-шеринга
# Summary (EN): Opt-in NFSv4 server (export /srv/nfs) and client (mount desktop).
#
# Цель:
#   Быстрая Linux-to-Linux передача файлов в LAN. Samba — для универсального
#   доступа (включая Android/Windows). Syncthing — для непрерывной синхронизации.
#   NFS — для случая "хочу залить 50GB с одного Linux-хоста на другой здесь и сейчас".
#
# Контракт:
#   Опции:
#     pro.nfs.server.enable   — на desktop: поднять nfsd, экспортировать /srv/nfs
#     pro.nfs.client.enable   — на остальных: монтировать desktop:/srv/nfs → /mnt/desktop
#     pro.nfs.server.exportPath — что экспортировать (default: /srv/nfs)
#     pro.nfs.server.allowedClients — CIDR-список (default: 192.168.0.0/16, 10.0.0.0/8)
#
# Побочные эффекты:
#   - server: открывает 2049/tcp+udp + mountd/rquotad/statd в firewall;
#     создаёт /srv/nfs (2775 root:pro) если отсутствует.
#   - client: добавляет fstab-запись для desktop.local:/srv/nfs → /mnt/desktop,
#     использует NFSv4.2, soft mount с reconnect.
#
# Предпосылки:
#   На сервере и клиенте должны быть одинаковые UID для az/za/la/bo (это
#   обеспечивается NixOS, см. pro-users.nix).
#
# Как проверить (Proof):
#   На сервере: `rpcinfo -p | grep nfs`, `exportfs -v`
#   На клиенте: `mount | grep nfs`, `ls -la /mnt/desktop`
#
# Last reviewed: 2026-06-09
{ config, lib, pkgs, ... }:

let
  cfg = config.pro.nfs;
  defaultExport = "/srv/nfs";
  defaultMount = "/mnt/desktop";
  defaultServer = "desktop";  # canonical pro-nix file server hostname
in
{
  options.pro.nfs = {
    server = {
      enable = lib.mkEnableOption "Export /srv/nfs via NFSv4 on this host";
      exportPath = lib.mkOption {
        type = lib.types.str;
        default = defaultExport;
        description = "Directory to export (read-write for the pro group).";
      };
      allowedClients = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "192.168.0.0/16" "10.0.0.0/8" "172.16.0.0/12" ];
        description = "CIDR ranges allowed to mount the export.";
      };
    };
    client = {
      enable = lib.mkEnableOption "Auto-mount desktop:/srv/nfs at /mnt/desktop";
      server = lib.mkOption {
        type = lib.types.str;
        default = defaultServer;
        description = "Hostname of the NFS server (without .local).";
      };
      remotePath = lib.mkOption {
        type = lib.types.str;
        default = "/srv/nfs";
        description = "Path exported on the server.";
      };
      mountPoint = lib.mkOption {
        type = lib.types.str;
        default = defaultMount;
        description = "Where to mount the share on the client.";
      };
    };
  };

  config = lib.mkMerge [

    # ─── SERVER ────────────────────────────────────────────────────────────
    (lib.mkIf cfg.server.enable {
      # nfsd (NFSv4) + вспомогательные демоны. nfs-mountd нужен для
      # NFSv3 fallback, оставляем включённым — стоит копейки, выручает
      # со старыми клиентами (macOS Finder по умолчанию v3).
      services.nfs.server = {
        enable = true;
        # Leave daemon tuning to NixOS defaults; helper daemons (lockd,
        # mountd) and ports are managed by the `services.nfs.server` module
        # in nixpkgs. Avoid setting potentially non-existent nested options.
        # Не включаем Kerberos — sec=sys достаточно для доверенной LAN
        # с одинаковыми UID. Если добавим AD/SSSD позже — переключим.
      };

      # Firewall: NFSv4 хочет 2049/tcp+udp. mountd/lockd/statd в новых
      # nixpkgs биндят на фиксированные порты (по rpcbind) — мы их
      # ограничиваем через rpcbind-allow правилами.
      networking.firewall = {
        allowedTCPPorts = [ 2049 20048 32767 32765 ];  # nfsd, mountd, statd, lockd
        allowedUDPPorts = [ 2049 20048 32767 32765 ];
      };

      # /etc/exports: rw,sync,no_subtree_check,sec=sys,fsid=0 (root export для NFSv4)
      # idmapd на клиенте маппит nobody/nogroup для чужих UID — поэтому
      # добавляем anonuid/anongid = 0 (root) и не делаем root_squash.
      services.nfs.server.exports =
        let
          opts = "rw,sync,no_subtree_check,no_root_squash,sec=sys,fsid=0,crossmnt";
          hostSpecs = map (host: "${host}(${opts})") cfg.server.allowedClients;
        in "${cfg.server.exportPath} ${lib.concatStringsSep " " hostSpecs}";

      # Пакеты: nfs-utils уже подтянется через services.nfs.server, но
      # добавим явно в профиль для удобства диагностики.
      environment.systemPackages = with pkgs; [ nfs-utils rpcbind ];
    })

    # ─── CLIENT ────────────────────────────────────────────────────────────
    (lib.mkIf cfg.client.enable {

      # Mount: NFSv4.2, soft (не зависаем при обрыве), _netdev (ждём сети),
      # noatime (меньше IO).
      #
      # Таймауты — минимальные, чтобы `opendir(/mnt/desktop)` возвращал
      # ошибку через ~3 с, а не через 25+ с:
      #   timeo=10              — 1 секунда (десятые доли) на одну попытку NFS
      #   retrans=1             — одна попытка; с `soft` сразу EIO после таймаута
      #   x-systemd.mount-timeout=3s — жёсткий лимит systemd на mount-юнит
      #                            (без него systemd ретраит холодный старт
      #                            долго и boot ощутимо висит, пока ARP сходится)
      #   nofail                — не блокировать загрузку, если шари нет
      #
      # Используем NixOS-managed systemd.automounts (НЕ fstab-генератор)
      # чтобы сделать mount ленивым: реальная попытка mount происходит
      # только при обращении к /mnt/desktop. Это:
      #   1. Не валит `nixos-rebuild switch`, когда desktop недоступен —
      #      активация трогает только .automount (CanReload=yes для
      #      Nix-managed unit), а .mount не стартует до первого access.
      #   2. Делает шару опциональной: хочешь — зашёл в /mnt/desktop,
      #      и она подмонтировалась; не нужно — просто не трогаешь путь.
      #
      # NB: если бы мы оставили `x-systemd.automount` в fstab-опциях,
      # systemd-fstab-generator создал бы mnt-desktop.automount с
      # CanReload=no, и `nixos-rebuild switch` падал бы с code 4 при
      # каждой правке /etc. Поэтому automount объявлен через NixOS-опцию,
      # а не через fstab.
      systemd.mounts = [ {
        name = "mnt-desktop.mount";
        what = "${cfg.client.server}.local:${cfg.client.remotePath}";
        where = cfg.client.mountPoint;
        # Почему без wantedBy: mount стартует только когда automount-unit
        # его дёрнет при обращении к /mnt/desktop. Если оставить
        # wantedBy=[multi-user.target], активация при switch попытается
        # запустить mount — и упадёт, если NFS-сервер недоступен.
        # Почему Options — одна строка, а не список:
        #   systemd `[Mount].Options=` — единственное поле, не повторяется;
        #   список из 9 элементов NixOS рендерит как 9 отдельных `Options=`,
        #   и каждое следующее перезаписывает предыдущее (остаётся только
        #   `noatime`). Comma-separated строка — канонический формат.
        mountConfig = {
          Options = "vers=4.2,rsize=1048576,wsize=1048576,soft,timeo=10,retrans=1,_netdev,nofail,noatime,x-systemd.mount-timeout=3s";
        };
      } ];

      # Lazy-mount через NixOS-managed automount unit. Стартует при
      # загрузке, но реальный mount происходит только при первом
      # обращении к /mnt/desktop. Если сервер недоступен — `ls /mnt/desktop`
      # вернёт ошибку через ~3 с (без зависания), а `just switch` пройдёт.
      systemd.automounts = [ {
        where = cfg.client.mountPoint;
        wantedBy = [ "multi-user.target" ];
        automountConfig.IdleTimeoutSec = "5min";
      } ];

      # nfs-utils для showmount, mountstats и т.п.
      environment.systemPackages = with pkgs; [ nfs-utils ];
    })
  ];
}
