+++
title = "desktop"
template = "page.html"
weight = 1

[extra]
tldr = "Сервер, LAN-шлюз, headscale control plane, NFS-сервер, Tor-узел. systemd-boot (EFI), linuxPackages_latest, KVM-intel, zram включён, audit выключен (проблема с symlink-путем)."

[[extra.next]]
title = "cf19"
url = "/hosts/cf19/"

[[extra.next]]
title = "Все хосты"
url = "/hosts/"
+++

# desktop

`desktop` — always-on башня, которая служит control plane'ом
кластера. Это единственный хост с `headscale.enable = true`,
единственный хост, экспортирующий NFS, и единственный LAN-шлюз.

* **Класс.** Десктоп-башня, always on.
* **Загрузка.** systemd-boot (EFI).
* **Ядро.** `linuxPackages_latest` (новее остальных хостов).
* **Роли.** `server, headscale, lan-gw, nfs, tor`.
* **Headscale-роль.** Единственный control plane для WireGuard-mesh.
* **NFS-роль.** Экспортирует `/srv/nfs` в LAN; члены группы `pro`
  могут писать, setgid.
* **LAN-gw-роль.** Маршрутизирует tailnet-клиентский трафик через
  основной uplink через MASQUERADE.

## Железо / ядро

```
boot.loader.systemd-boot.enable = lib.mkForce true;
boot.loader.grub.enable         = lib.mkForce false;
boot.loader.efi.canTouchEfiVariables = lib.mkForce true;
boot.loader.efi.efiSysMountPoint    = "/boot";
boot.loader.systemd-boot.configurationLimit = 6;
boot.loader.timeout = 5;

boot.kernelPackages = lib.mkForce pkgs.linuxPackages_latest;
boot.kernelParams = [ "nvme_core.default_ps_max_latency_us=5500" ];
boot.extraModprobeConfig = "options btusb enable_autosuspend=0";

boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod" ];
boot.initrd.kernelModules = [ ];
boot.kernelModules = [ "kvm-intel" ];
boot.extraModulePackages = [ ];

hardware.cpu.intel.updateMicrocode = true;
```

`btusb enable_autosuspend=0` — явный quirk. Bluetooth-клавиатуры
теряют ввод, если USB-autosuspend-таймер срабатывает во время
длинной Emacs-сессии. Модули ядра — это **available**-in-initrd
набор, не loaded-набор, так что initrd может подтянуть правильный
драйвер без явного `boot.initrd.kernelModules`.

`KVM-intel` включён для VM (хост иногда запускает несколько
тестовых VM — `vm-switch-loop.sh` гоняет regression-тест).

## Хранилище

```
fileSystems."/" = lib.mkForce {
  device = "/dev/disk/by-uuid/<root-uuid>";
  fsType = "ext4";
  options = [ "noatime" ];
};

fileSystems."/boot" = lib.mkForce {
  device = "/dev/disk/by-uuid/<efi-uuid>";
  fsType = "vfat";
  options = [ "fmask=0077" "dmask=0077" ];
};

fileSystems."/mnt/storage" = lib.mkForce {
  device = "/dev/disk/by-uuid/<storage-uuid>";
  fsType = "ext4";
  options = [ "noatime" ];
};

swapDevices = [ ];
```

Три файловые системы, без swap-устройства. zram-slice заменяет
swap целиком (см. ниже).

`noatime` на `/` и `/mnt/storage` уменьшает запись на диск для
домашней директории с интенсивным трафиком и media-архивом.

## Питание и память

```
services.zramSlice = {
  enable = true;
  size = "auto";
};
```

`size = "auto"` — это `50% RAM, ограничение 16384 MB` (см.
`modules/zram-slice.nix`). На 32 GB башне это даёт 16 GB zram-swap.
Активно используется во время пауз GC в Emacs и когда
`trivy image --severity HIGH,CRITICAL` сканирует многогигабайтный
Docker-образ.

## Resolved / Avahi

```
services.resolved = {
  enable = true;
  llmnr = "false";   # NB: NixOS-опция — enum [ "true" "resolve" "false" ] — СТРОКА
  extraConfig = builtins.readFile ../../conf/resolved-extra.conf;
};
```

`llmnr = "false"` — **строка**, не bool — NixOS-опция это enum, а
не `types.bool`. `MulticastDNS=no` и `LLMNR=no` дописываются через
`extraConfig` (из `conf/resolved-extra.conf`), чтобы Avahi был
единственным mDNS-стеком.

## Audit

```
security.audit.enable = false;
```

`auditctl` не может наложить watch-правила на `/.host-etc/`
symlink'и — audit-подсистема несовместима с symlink-based
`/etc/` layout NixOS'а. Trade-off: на этом хосте нет audit. На нём
работают headscale control plane, NFS-сервер и LAN-шлюз, так что
потеря audit нетривиальна — пользователь компенсирует мониторингом
journal'а и fail2ban.

## NFS

```
pro.nfs.server.enable = true;
pro.nfs.server.exportPath = "/srv/nfs";
# pro.nfs.client.enable — НАМЕРЕННО НЕ включён на этом хосте.
# Loopback-монит с этого хоста на самого себя упадёт с
# "No such file or directory" от mountd. NFS-клиент нужен только
# на cf19/huawei/vm.
```

Export имеет
`rw,sync,no_subtree_check,no_root_squash,sec=sys,fsid=0,crossmnt`.
Allowed clients: 3 RFC1918 CIDR'а.

## Headscale

```
headscale.enable = lib.mkForce true;
pro.network.allowSubnetRouter = lib.mkForce true;
```

См. [Архитектура → Сетевые слои → headscale](architecture/network.md#слой-2-mesh-headscale)
для per-host инварианта (только один control plane).

## Что на этом хосте

* `desktop-heavy` composition: chromium, firefox, telegram-desktop,
  element-desktop, jami, weechat, ffmpegthumbnailer, baobab,
  pavucontrol, deluge, steam, steam-run, copyq, dunst, flameshot,
  playerctl.
* Chromium-обёртка: `systemd-run --user --scope -p MemoryMax=4500M
  -p MemoryHigh=4G -p CPUQuota=90%`.
* Firefox-обёртка: `MemoryMax=2500M -p MemoryHigh=2G -p CPUQuota=90%`.
* NFS-сервер, Syncthing (gui 127.0.0.1:8384, openDefaultPorts = false,
  одна shared-папка `/srv/syncthing/share`), Samba-сервер (private +
  public shares, члены группы `pro` могут писать).

## Post-switch чек-лист

```bash
# 1. SSH-ключи
ssh-copy-id -i ~/.ssh/id_ed25519.pub <user>@desktop.local

# 2. Avahi
systemctl status avahi-daemon
avahi-browse -rt _ssh._tcp | grep desktop

# 3. NFS-export
install -d -m 2775 -o root -g pro /srv/nfs
exportfs -v | grep /srv/nfs

# 4. Headscale — бэкап noise-ключа ОДИН РАЗ
sudo cp /var/lib/headscale/noise_private.key /etc/headscale/
sudo chmod 0600 /etc/headscale/noise_private.key
# Запинить через local.nix: headscale.settings.noise.private_key = "<base64>"

# 5. Headscale user + preauthkey
sudo headscale users create <user>
sudo headscale preauthkeys create --user <user> --reusable --expiration 24h

# 6. Firewall (если принимать регистрации из WAN)
# Добавить в local.nix: networking.firewall.allowedTCPPorts = [ 8080 ];

# 7. Tor (если хотите onion-имя)
# См. modules/pro-privacy.nix + scripts/ops-ensure-tor.sh

# 8. zram
systemctl status zram.slice

# 9. LAN-gw
sysctl net.ipv4.ip_forward    # должен быть 1
ip route show default
```
