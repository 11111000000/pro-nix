+++
title = "huawei"
template = "page.html"
weight = 3

[extra]
tldr = "Intel-iGPU laptop, EFI boot, sound quirks (snd-intel-dspcfg dsp_driver=1), Haskell toolchain, NFS disabled (different subnet), heaviest composition."

[[extra.next]]
title = "vm"
url = "/hosts/vm/"

[[extra.next]]
title = "All hosts"
url = "/hosts/"
+++

# huawei

`huawei` is a **modern Intel-laptop** in the cluster. Where `cf19` is
held together by BIOS-era workarounds, `huawei` is held together by
the **Intel audio firmware story** (snd-intel-dspcfg + SOF). The
host is also the **Haskell development machine** — it imports
`pro-haskell.nix` and carries the heaviest package composition.

* **Class.** Laptop, EFI boot, modern Intel CPU + iGPU.
* **Boot.** systemd-boot, no NVRAM writes from this host.
* **Kernel.** `linuxPackages_6_6` (LTS).
* **Roles.** `laptop, tor`.

## Kernel parameters

```
boot.kernelParams = [
  "mem_sleep_default=s2idle"
  "i915.enable_psr=0"
  "nvme_core.default_ps_max_latency_us=0"
  "acpi_backlight=native"
];
```

* `mem_sleep_default=s2idle` — modern suspend mode (this laptop does
  not support S3 reliably).
* `i915.enable_psr=0` — disable Intel Panel Self Refresh. PSR causes
  occasional screen tearing on this iGPU; disabling it has no
  noticeable power cost on a modern panel.
* `nvme_core.default_ps_max_latency_us=0` — disable NVMe power-state
  transitions. The transitions cause IO latency spikes under load.
* `acpi_backlight=native` — use the kernel's native ACPI backlight
  driver instead of the vendor-specific one. The vendor driver is
  known to flicker on this laptop.

## The audio modprobe

```
boot.extraModprobeConfig = ''
  options snd-intel-dspcfg dsp_driver=1
'';

hardware.firmware = [ pkgs.sof-firmware ];
```

`dsp_driver=1` **forces the SOF (Sound Open Firmware) path** for the
Intel onboard audio. The default (`dsp_driver=0` for some HDA
platforms, `dsp_driver=2` for the legacy path) does not initialize
the codec correctly on this machine. The `sof-firmware` package is
required because SOF needs firmware blobs at boot.

If `dsp_driver=1` is removed, audio on `huawei` is dead. There is
no in-OS way to switch it back without a reboot.

## The storage layout

```
fileSystems."/" = lib.mkForce {
  device = "/dev/disk/by-uuid/b7a0681a-d1e2-4898-b213-f060d77b292a";
  fsType = "ext4";
};

fileSystems."/boot" = lib.mkForce {
  device = "/dev/disk/by-uuid/6DD0-A9CB";
  fsType = "vfat";
  options = [ "fmask=0077" "dmask=0077" ];
};

swapDevices = [ { device = "/dev/disk/by-uuid/422bf68d-025a-4c1b-a3ba-c282ab7d4884"; } ];

boot.resumeDevice = "/dev/nvme0n1p3";
```

EFI boot (vfat), `/` on ext4, swap on a dedicated NVMe partition.
`resumeDevice` is the swap partition (used for hibernation).

## zram

```
services.zramSlice = {
  enable = true;
  size = "auto";
};
```

`huawei` has both disk swap and zram. The disk swap is for
hibernation; the zram is for normal-pressure memory spikes
(Emacs + Haskell LSP + a couple of Telegram conversations).

## NFS — disabled

```
pro.nfs.client.enable = lib.mkForce false;
```

`huawei` is on `192.168.34.x`; `desktop` is on `192.168.1.x`. mDNS
does not cross subnets by default (without explicit relay
configuration). Until headscale is set up to bridge the subnets,
NFS from `huawei` is impractical.

The host's `composition.nix` has a comment explaining the TODO:

```nix
# NFS-клиент: монтируем desktop:/srv/nfs автоматически по обращению.
# Временно отключено: desktop на другой подсети (192.168.1.x vs 192.168.34.x), mDNS не работает.
# TODO: включить после решения проблемы сети или поднятия headscale.
pro.nfs.client.enable = lib.mkForce false;
```

## Headscale — disabled

`huawei` is a laptop, not the control plane. `mkForce false` like
`cf19`.

## The session

`huawei` does **not** import `profile-exwm-minimal.nix`. It imports
`pro-heavy-desktop.nix` (chromium, telegram, element, jami, etc.)
and starts Sway manually (no `pro.profiles.exwmMinimal.enable` set
anywhere on this host).

The user prefers Sway on this laptop because the iGPU has better
Wayland support than X11 in the 6.6 kernel.

## The Haskell toolchain

```nix
imports = [
  ../../modules/pro-users.nix
  ../../modules/pro-haskell.nix
  ../../modules/pro-heavy-desktop.nix
];
```

`modules/pro-haskell.nix` brings in:

* `ghc` — the Glasgow Haskell Compiler.
* `haskell-language-server` — the LSP server.
* `cabal-install` — Cabal.
* `stack` — Stack (alternative build tool).
* `ghcid` — fast recompile-and-reload REPL.
* `hlint` — the linter.
* `fourmolu` — the formatter.

`ghcup` is **not** used. Every Haskell tool comes from nixpkgs.

The Emacs side is `emacs/base/modules/pro-haskell.el` — five
interactive commands (`pro-haskell-load-buffer`,
`pro-haskell-switch-to-repl`, `pro-haskell-format-buffer`,
`pro-haskell-lint`, `pro-haskell-browse-haddock`) and the eglot
registration for `haskell-language-server-wrapper`.

## The composition — heaviest of the four

```nix
{ pkgs, ... }:
let
  desktopHeavy = import ../../modules/system-package-sets-desktop-heavy.nix { inherit pkgs; };
  privacy      = import ../../modules/system-package-sets-privacy.nix { inherit pkgs; };
  lsp          = import ../../modules/system-package-sets-lsp.nix { inherit pkgs; };
  media        = import ../../modules/system-package-sets-media.nix { inherit pkgs; };
  runtime      = import ../../modules/system-package-sets-runtime.nix { inherit pkgs; };
  dev          = import ../../modules/system-package-sets-dev.nix { inherit pkgs; };
  exwm         = import ../../modules/system-package-sets-exwm.nix { inherit pkgs; };
  tor          = import ../../modules/system-package-sets-tor.nix { inherit pkgs; };
in
{
  environment.systemPackages = with pkgs;
    runtime.runtimePackages
    ++ dev.devPackages
    ++ exwm.exwmPackages
    ++ lsp.lspPackages
    ++ privacy.privacyPackages
    ++ media.mediaPackages
    ++ tor.torControlPackages
    ++ (import ../../modules/system-package-sets-desktop-heavy.nix { inherit pkgs; }).desktopHeavyPackages
    ++ [ tor-browser ];
}
```

Eight composition files plus a direct `tor-browser` package. The
total closure is the largest in the cluster.

## Post-switch checklist

```bash
# 1. SSH keys
ssh-copy-id -i ~/.ssh/id_ed25519.pub az@huawei.local

# 2. SOF audio
lsmod | rg snd_intel_dspcfg   # module loaded
lsmod | rg snd_sof            # SOF driver loaded
speaker-test -c 2 -t wav    # verify stereo output

# 3. Haskell
ghc --version                # should print GHC version
cabal --version              # should print Cabal version
stack --version              # should print Stack version
which haskell-language-server-wrapper

# 4. Intel GPU
cat /proc/cmdline | tr ' ' '\n' | rg i915
# Should include: i915.enable_psr=0

# 5. Avahi
getent hosts desktop.local
getent hosts huawei.local

# 6. Network reachability (huawei is on 192.168.34.x)
#   - To reach desktop, either be on the same subnet, or use
#     headscale (once enabled), or use the Tor onion (if configured).
#   - Local network is fine.

# 7. Sway session
#   Start Sway from a TTY:
sway
#   - If wl_compositor crashes 2s after start, check
#     ~/.cache/emacs-startup/ for logs.
```
