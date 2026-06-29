+++
title = "huawei"
template = "page.html"
weight = 3

[extra]
tldr = "Intel-iGPU ноутбук, EFI-загрузка, sound quirks (snd-intel-dspcfg dsp_driver=1), Haskell-toolchain, NFS выключен (другая подсеть), самая тяжёлая composition."

[[extra.next]]
title = "vm"
url = "/hosts/vm/"

[[extra.next]]
title = "Все хосты"
url = "/hosts/"
+++

# huawei

`huawei` — **современный Intel-ноутбук** в кластере. Где `cf19`
удерживается обходами BIOS-эры, `huawei` удерживается
**Intel-аудио-историей** (snd-intel-dspcfg + SOF). Хост также —
**Haskell-разработка-машина** — импортирует `pro-haskell.nix` и несёт
самую тяжёлую package-composition.

* **Класс.** Ноутбук, EFI-загрузка, современный Intel CPU + iGPU.
* **Загрузка.** systemd-boot, без NVRAM-записей с этого хоста.
* **Ядро.** `linuxPackages_6_6` (LTS).
* **Роли.** `laptop, tor`.

## Kernel-параметры

```
boot.kernelParams = [
  "mem_sleep_default=s2idle"
  "i915.enable_psr=0"
  "nvme_core.default_ps_max_latency_us=0"
  "acpi_backlight=native"
];
```

* `mem_sleep_default=s2idle` — современный suspend-режим (этот
  ноутбук не поддерживает S3 надёжно).
* `i915.enable_psr=0` — отключить Intel Panel Self Refresh. PSR
  вызывает occasional screen tearing на этом iGPU; отключение не
  имеет заметной power-cost на современной панели.
* `nvme_core.default_ps_max_latency_us=0` — отключить NVMe
  power-state-transitions. Transitions вызывают IO-latency-спайки
  под нагрузкой.
* `acpi_backlight=native` — использовать нативный ACPI-backlight-драйвер
  ядра вместо vendor-specific. Vendor-драйвер моргает на этом
  ноутбуке.

## Аудио-modprobe

```
boot.extraModprobeConfig = ''
  options snd-intel-dspcfg dsp_driver=1
'';

hardware.firmware = [ pkgs.sof-firmware ];
```

`dsp_driver=1` **форсирует SOF (Sound Open Firmware) путь** для
Intel onboard-аудио. Default (`dsp_driver=0` для некоторых HДА-платформ,
`dsp_driver=2` для legacy-пути) не инициализирует кодек корректно
на этой машине. Пакет `sof-firmware` нужен, потому что SOF требует
firmware-блобы при загрузке.

Если `dsp_driver=1` убрать, аудио на `huawei` мертво. Нет in-OS
способа переключить обратно без перезагрузки.

## Storage layout

```
fileSystems."/" = lib.mkForce {
  device = "/dev/disk/by-uuid/<root-uuid>";
  fsType = "ext4";
};

fileSystems."/boot" = lib.mkForce {
  device = "/dev/disk/by-uuid/<efi-uuid>";
  fsType = "vfat";
  options = [ "fmask=0077" "dmask=0077" ];
};

swapDevices = [ { device = "/dev/disk/by-uuid/<swap-uuid>"; } ];

boot.resumeDevice = "/dev/nvme0n1p3";
```

EFI-загрузка (vfat), `/` на ext4, swap на отдельном NVMe-разделе.
`resumeDevice` — swap-раздел (используется для гибернации).

## zram

```
services.zramSlice = {
  enable = true;
  size = "auto";
};
```

`huawei` имеет и дисковый swap, и zram. Дисковый swap — для
гибернации; zram — для нормальных memory-спайков
(Emacs + Haskell LSP + пара Telegram-разговоров).

## NFS — выключен

```
pro.nfs.client.enable = lib.mkForce false;
```

`huawei` на `192.168.34.x`; `desktop` на `192.168.1.x`. mDNS не
пересекает подсети по умолчанию (без явной relay-конфигурации).
Пока headscale не настроен бриджить подсети, NFS с `huawei`
непрактичен.

В host-овском `composition.nix` есть комментарий с объяснением
TODO:

```nix
# NFS-клиент: монтируем desktop:/srv/nfs автоматически по обращению.
# Временно отключено: desktop на другой подсети (192.168.1.x vs 192.168.34.x), mDNS не работает.
# TODO: включить после решения проблемы сети или поднятия headscale.
pro.nfs.client.enable = lib.mkForce false;
```

## Headscale — выключен

`huawei` — ноутбук, не control plane. `mkForce false` как `cf19`.

## Сессия

`huawei` **не** импортирует `profile-exwm-minimal.nix`. Он
импортирует `pro-heavy-desktop.nix` (chromium, telegram, element,
jami, и т.д.) и запускает Sway вручную (без
`pro.profiles.exwmMinimal.enable` где-либо на этом хосте).

Пользователь предпочитает Sway на этом ноутбуке, потому что iGPU
имеет лучшую Wayland-поддержку, чем X11, в ядре 6.6.

## Haskell-toolchain

```nix
imports = [
  ../../modules/pro-users.nix
  ../../modules/pro-haskell.nix
  ../../modules/pro-heavy-desktop.nix
];
```

`modules/pro-haskell.nix` приносит:

* `ghc` — Glasgow Haskell Compiler.
* `haskell-language-server` — LSP-сервер.
* `cabal-install` — Cabal.
* `stack` — Stack (альтернативный build-tool).
* `ghcid` — быстрый recompile-and-reload REPL.
* `hlint` — линтер.
* `fourmolu` — форматтер.

`ghcup` **не** используется. Каждый Haskell-инструмент приходит
из nixpkgs.

Emacs-сторона — `emacs/base/modules/pro-haskell.el` — пять
интерактивных команд (`pro-haskell-load-buffer`,
`pro-haskell-switch-to-repl`, `pro-haskell-format-buffer`,
`pro-haskell-lint`, `pro-haskell-browse-haddock`) и eglot-регистрация
для `haskell-language-server-wrapper`.

## Composition — самая тяжёлая из четырёх

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

Восемь composition-файлов плюс прямой `tor-browser`. Closure —
самый большой в кластере.

## Post-switch чек-лист

```bash
# 1. SSH-ключи
ssh-copy-id -i ~/.ssh/id_ed25519.pub <user>@huawei.local

# 2. SOF-аудио
lsmod | rg snd_intel_dspcfg   # модуль загружен
lsmod | rg snd_sof            # SOF-драйвер загружен
speaker-test -c 2 -t wav    # проверить стерео-выход

# 3. Intel GPU
cat /proc/cmdline | tr ' ' '\n' | rg i915
# Должно включать: i915.enable_psr=0

# 4. Haskell
ghc --version                # должен напечатать версию GHC
cabal --version              # должен напечатать версию Cabal
stack --version              # должен напечатать версию Stack
which haskell-language-server-wrapper

# 5. Avahi / NFS — обратите внимание, huawei на другой подсети
getent hosts desktop.local
# getent hosts desktop.local ожидаемо пуст, пока
# headscale не свяжет подсети.
ls /mnt/desktop                  # 3-секундный таймаут (autofs nofail)

# 6. Sway-сессия
# Запустите Sway из TTY:
sway
# Если wl_compositor падает 2с после старта, посмотрите
# ~/.cache/emacs-startup/ в логах.
```
