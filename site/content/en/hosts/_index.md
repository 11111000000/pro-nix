+++
title = "Hosts"
sort_by = "weight"
template = "section.html"

[extra]
tldr = "Four machines, four design stories. The repo encodes each hardware quirk as a Nix override, not as documentation."
+++

Each host is a single directory under `hosts/` with two files:

```
hosts/<name>/
├── configuration.nix    # hardware, kernel, hostname, special-case mkForce
└── composition.nix      # environment.systemPackages composition
```

There is no shared "machine template" — what the hosts share lives in
`modules/`. The host directory only carries the deltas.

## desktop — server, LAN gateway, headscale control plane

* **Class.** Desktop tower. Always-on.
* **Boot.** systemd-boot (EFI), `boot.loader.efi.canTouchEfiVariables = true`,
  `boot.loader.systemd-boot.configurationLimit = 6`.
* **Kernel.** `linuxPackages_latest` (newer than the other hosts). `KVM-intel`
  module enabled. `nvme_core.default_ps_max_latency_us=5500`.
* **Storage.** `/` ext4, `/boot` vfat, separate `/mnt/storage` ext4. No swap
  device — `zramSlice.enable = true, size = "auto"` (50% RAM, capped 16384MB).
* **Network.** LAN-gateway role: `pro.network.allowSubnetRouter = true`
  (IPv4 forwarding + IPv6 forwarding + MASQUERADE on default route).
  `services.resolved.llmnr = "false"` (NB: the enum value is a string).
  `security.audit.enable = false` — `auditctl` cannot watch `/.host-etc/`
  symlinks on this host.
* **Services.** NFS server (`/srv/nfs`, members of group `pro` can write),
  headscale (`base_domain = "pro-nix.ts.net"`, listens on `0.0.0.0:8080`).

## cf19 — laptop, BIOS boot, dbus-regression

* **Class.** Panasonic Let's Note CF-MX, x86 laptop, BIOS (not EFI).
* **Boot.** GRUB on `/dev/sda`, `boot.loader.efi.canTouchEfiVariables = mkForce false`.
* **Kernel params.** `i8042.reset i8042.nomux mitigations=off preempt=full
  mem_sleep_default=s2idle`.
* **WiFi.** `iwlwifi 11n_disable=8`, `iwlmvm uapsd_disable=1` — power-save is
  off because resume from s2idle can leave the chip un-initialised. The
  `ops-wifi-recover.sh` (escalating `nmcli radio wifi off/on` →
  `connection reload` → `systemctl try-restart NetworkManager`) is wired into
  `powerManagement.{resume,powerUp}Commands` via `lib.mkAfter`.
* **D-Bus.** Four `systemd.services.dbus.*IfChanged` options are
  `lib.mkForce false` to prevent the switch-time dbus-broker restart that
  historically caused `cf19` to drop to TTY during `nixos-rebuild switch`.
* **Storage.** `/`, `/boot` (ext4, no EFI), `/mnt/sda4` (ext4, noatime).
  Swap on dedicated UUID.
* **GUI.** EXWM-minimal + heavy-desktop + Sway + i3 sessions. Cinnamon
  `mkForce false`, fbterm-tty2 `mkForce false`.
* **Network.** NFS client only (`pro.nfs.client.enable = true` →
  `desktop.local:/srv/nfs` at `/mnt/desktop`, autofs, 3-second timeout).
  `headscale.enable = lib.mkForce false`.

## huawei — laptop, Intel iGPU, Haskell

* **Class.** Intel-based laptop, Wayland-leaning.
* **Boot.** systemd-boot (EFI), `canTouchEfiVariables = mkForce false`.
* **Kernel params.** `mem_sleep_default=s2idle i915.enable_psr=0
  nvme_core.default_ps_latency_us=0 acpi_backlight=native`.
* **Modprobe.** `options snd-intel-dspcfg dsp_driver=1` to force the SOF
  firmware path for the Intel onboard audio.
* **Firmware.** `pkgs.sof-firmware` is in `hardware.firmware`.
* **Storage.** `/` ext4, `/boot` vfat (EFI), swap on dedicated NVMe partition.
  `zramSlice.enable = true`.
* **GUI.** heavy-desktop only (no `profile-exwm-minimal.nix` import). The
  user runs Sway manually, not through the EXWM-minimal glue.
* **Network.** NFS **disabled**: `desktop` is on `192.168.1.x`, `huawei` is
  on `192.168.34.x`, mDNS does not cross subnets. Comment in
  `hosts/huawei/configuration.nix:60` notes the TODO to re-enable after
  headscale is in place.
* **Haskell.** Imports `pro-haskell.nix` — `ghc`, `haskell-language-server`,
  `cabal-install`, `stack`, `ghcid`, `hlint`, `fourmolu`.
* **Composition.** The heaviest of the four: `runtime + dev + exwm + lsp +
  privacy + media + tor + desktopHeavy + tor-browser`.

## vm — isolated test VM

* **Class.** Single-purpose VM, no GUI.
* **Host constructor.** Built by `mkVmHost` in `flake.nix:92-102` (NOT by
  `mkHost`). The minimal baseline is `packages-runtime + tty-console +
  searxng + pro-users + pro-docker + pro-nfs + pro-spellcheck`. There is
  **no import of `configuration.nix`**, so `headscale.*` is not even a
  valid attribute in the evaluation.
* **Boot.** systemd-boot (EFI), `canTouchEfiVariables = mkForce false`.
* **Storage.** `/` on `/dev/sda1` (ext4). No swap, no separate `/boot`.
* **Security.** `security.sudo.wheelNeedsPassword = mkForce false`,
  `users.users.root.password = ""`. These are explicit — the file comment
  states "только для изолированной VM, в проде замените".
* **GUI.** `services.xserver.enable = mkForce false`,
  `services.displayManager.enable = mkForce false`.
* **Network.** `pro.nfs.client.enable = true` so the VM can mount
  `desktop.local:/srv/nfs` for testing.

## Reading order

If you want to understand the host-quirk story end-to-end:

1. `modules/pro-hosts.nix` — the four-line registry.
2. `modules/host-policies.nix` — Tor defaults, SSH hardening, per-host
   kernel mods (huawei bridges, cf19 iwlwifi).
3. `hosts/desktop/configuration.nix` — the most complex of the four.
4. `hosts/cf19/configuration.nix` — the dbus-regression override.
5. `flake.nix:104-109` — see how the four host configs plug into the flake.
