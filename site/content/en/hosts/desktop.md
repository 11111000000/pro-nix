+++
title = "desktop"
template = "page.html"
weight = 1

[extra]
tldr = "Server, LAN gateway, headscale control plane, NFS server, Tor node. systemd-boot (EFI), linuxPackages_latest, KVM-intel, zram enabled, audit disabled (symlink path issue)."

[[extra.next]]
title = "cf19"
url = "/hosts/cf19/"

[[extra.next]]
title = "All hosts"
url = "/hosts/"
+++

# desktop

`desktop` is the always-on tower that acts as the cluster's control
plane. It is the only host with `headscale.enable = true`, the only
host that exports NFS, and the only host that is a LAN gateway.

* **Class.** Desktop tower, always on.
* **Boot.** systemd-boot (EFI).
* **Kernel.** `linuxPackages_latest` (newer than the other hosts).
* **Roles.** `server, headscale, lan-gw, nfs, tor`.
* **Headscale role.** Single control plane for the WireGuard mesh.
* **NFS role.** Exports `/srv/nfs` to the LAN; members of group `pro`
  can write, setgid.
* **LAN-gw role.** Routes tailnet-client traffic through the main
  uplink via MASQUERADE.

## Hardware / kernel

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

The `btusb enable_autosuspend=0` is an explicit quirk — Bluetooth
keyboards drop input if the USB autosuspend timer fires during a
long Emacs session. The kernel modules are the
**available**-in-initrd set, not the loaded set, so the initrd can
pull the right driver without explicit `boot.initrd.kernelModules`.

`KVM-intel` is enabled for VMs (the host runs a few test VMs
occasionally — `vm-switch-loop.sh` exercises the regression test).

## Storage

```
fileSystems."/" = lib.mkForce {
  device = "/dev/disk/by-uuid/ef0ab8ba-27f8-4595-8595-79390078ef46";
  fsType = "ext4";
  options = [ "noatime" ];
};

fileSystems."/boot" = lib.mkForce {
  device = "/dev/disk/by-uuid/B994-87FC";
  fsType = "vfat";
  options = [ "fmask=0077" "dmask=0077" ];
};

fileSystems."/mnt/storage" = lib.mkForce {
  device = "/dev/disk/by-uuid/23ab71c8-d86f-4f92-802a-9cb706261f3f";
  fsType = "ext4";
  options = [ "noatime" ];
};

swapDevices = [ ];
```

Three filesystems, no swap device. The zram slice replaces swap
entirely (see below).

The `noatime` on `/` and `/mnt/storage` reduces disk writes for a
heavy-traffic home directory and a media-archive storage disk.

## Power and memory

```
services.zramSlice = {
  enable = true;
  size = "auto";
};
```

`size = "auto"` is `50% RAM, capped at 16384 MB` (see
`modules/zram-slice.nix`). On a 32 GB tower, this gives a 16 GB
zram swap. Used heavily during Emacs GC pauses and when the
`trivy image --severity HIGH,CRITICAL` job scans a multi-GB Docker
image.

## Resolved / Avahi

```
services.resolved = {
  enable = true;
  llmnr = "false";   # NB: NixOS option is enum [ "true" "resolve" "false" ] — STRING
  extraConfig = builtins.readFile ../../conf/resolved-extra.conf;
};
```

`llmnr = "false"` is **a string**, not a bool — the NixOS option is an
enum, not a `types.bool`. `MulticastDNS=no` and `LLMNR=no` are
appended via `extraConfig` (from `conf/resolved-extra.conf`) to make
Avahi the sole mDNS stack.

## Audit

```
security.audit.enable = false;
```

`auditctl` cannot watch `/.host-etc/` symlinks — the audit subsystem
is incompatible with NixOS's symlink-based `/etc/` layout. The
trade-off: no audit on this host. The headscale control plane, the
NFS server, and the LAN gateway are all on this host, so the loss
of audit is non-trivial — the user is expected to compensate with
journal monitoring and fail2ban.

## NFS

```
pro.nfs.server.enable = true;
pro.nfs.server.exportPath = "/srv/nfs";
# pro.nfs.client.enable — INTENTIONALLY NOT set on this host.
# A loopback mount from this host to itself would fail with
# "No such file or directory" from mountd. NFS client is for
# cf19/huawei/vm only.
```

The export has `rw,sync,no_subtree_check,no_root_squash,sec=sys,fsid=0,crossmnt`.
Allowed clients: 3 RFC1918 CIDRs.

## Headscale

```
headscale.enable = lib.mkForce true;
pro.network.allowSubnetRouter = lib.mkForce true;
```

See [Architecture → Network layers → headscale](architecture/network.md#layer-2-mesh-headscale)
for the per-host invariant (one control plane only).

## What is on this host

* `desktop-heavy` composition: chromium, firefox, telegram-desktop,
  element-desktop, jami, weechat, ffmpegthumbnailer, baobab,
  pavucontrol, deluge, steam, steam-run, copyq, dunst, flameshot,
  playerctl.
* Chromium wrapper: `systemd-run --user --scope -p MemoryMax=4500M
  -p MemoryHigh=4G -p CPUQuota=90%`.
* Firefox wrapper: `MemoryMax=2500M -p MemoryHigh=2G -p CPUQuota=90%`.
* NFS server, Syncthing (gui 127.0.0.1:8384, openDefaultPorts = false,
  single shared folder `/srv/syncthing/share`), Samba server
  (private + public shares, members of `pro` group can write).

## Post-switch checklist

```bash
# 1. SSH keys
ssh-copy-id -i ~/.ssh/id_ed25519.pub az@desktop.local

# 2. Avahi
systemctl status avahi-daemon
avahi-browse -rt _ssh._tcp | grep desktop

# 3. NFS export
install -d -m 2775 -o root -g pro /srv/nfs
exportfs -v | grep /srv/nfs

# 4. Headscale — back up the noise key ONCE
sudo cp /var/lib/headscale/noise_private.key /etc/headscale/
sudo chmod 0600 /etc/headscale/noise_private.key
# pin via local.nix: headscale.settings.noise.private_key = "<base64>"

# 5. Headscale user + preauthkey
sudo headscale users create az
sudo headscale preauthkeys create --user az --reusable --expiration 24h

# 6. Firewall (if accepting registrations from WAN)
# Add to local.nix: networking.firewall.allowedTCPPorts = [ 8080 ];

# 7. Tor (if you want the onion hostname)
# See modules/pro-privacy.nix + scripts/ops-ensure-tor.sh

# 8. zram
systemctl status zram.slice

# 9. LAN-gw
sysctl net.ipv4.ip_forward    # should be 1
ip route show default
```
