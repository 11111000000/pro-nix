+++
title = "Хосты"
sort_by = "weight"
template = "section.html"

[extra]
tldr = "Четыре машины, четыре design-story. Репозиторий кодирует каждую аппаратную особенность как Nix-override, а не как документацию."
+++

Каждый хост — отдельный каталог в `hosts/` с двумя файлами:

```
hosts/<name>/
├── configuration.nix    # железо, kernel, hostname, special-case mkForce
└── composition.nix      # environment.systemPackages composition
```

Нет общего «машинного шаблона» — то, что общего у хостов, лежит в
`modules/`. Каталог хоста несёт только дельты.

## desktop — сервер, LAN-шлюз, headscale control plane

* **Класс.** Десктоп-башня, always-on.
* **Загрузка.** systemd-boot (EFI), `boot.loader.efi.canTouchEfiVariables = true`,
  `boot.loader.systemd-boot.configurationLimit = 6`.
* **Ядро.** `linuxPackages_latest` (новее остальных хостов). Включён
  модуль `KVM-intel`. `nvme_core.default_ps_max_latency_us=5500`.
* **Хранилище.** `/` ext4, `/boot` vfat, отдельный `/mnt/storage` ext4.
  Без swap-устройства — `zramSlice.enable = true, size = "auto"`
  (50% RAM, ограничение 16384 MB).
* **Сеть.** LAN-шлюз: `pro.network.allowSubnetRouter = true`
  (IPv4 forwarding + IPv6 forwarding + MASQUERADE на default route).
  `services.resolved.llmnr = "false"` (NB: enum-значение — строка).
  `security.audit.enable = false` — `auditctl` не может наложить
  watch-правила на `/.host-etc/` symlink'и на этом хосте.
* **Сервисы.** NFS-сервер (`/srv/nfs`, члены группы `pro` могут писать,
  setgid), headscale (`base_domain = "pro-nix.ts.net"`, слушает
  `0.0.0.0:8080`).

## cf19 — ноутбук, BIOS-загрузка, dbus-regression

* **Класс.** Panasonic Let's Note CF-MX, x86-ноутбук, BIOS (не EFI).
* **Загрузка.** GRUB на `/dev/sda`, `boot.loader.efi.canTouchEfiVariables
  = mkForce false`.
* **Kernel-параметры.** `i8042.reset i8042.nomux mitigations=off
  preempt=full mem_sleep_default=s2idle`.
* **WiFi.** `iwlwifi 11n_disable=8`, `iwlmvm uapsd_disable=1` — power-save
  выключен, потому что resume из s2idle может оставить чип
  не-инициализированным. `ops-wifi-recover.sh` (эскалация
  `nmcli radio wifi off/on` → `connection reload` →
  `systemctl try-restart NetworkManager`) подключён к
  `powerManagement.{resume,powerUp}Commands` через `lib.mkAfter`.
* **D-Bus.** Четыре опции `systemd.services.dbus.*IfChanged` установлены
  в `lib.mkForce false`, чтобы предотвратить switch-time
  dbus-broker restart, который исторически валил `cf19` в TTY во
  время `nixos-rebuild switch`.
* **Хранилище.** `/`, `/boot` (ext4, без EFI), `/mnt/sda4` (ext4, noatime).
  Swap на отдельном UUID.
* **GUI.** EXWM-minimal + heavy-desktop + Sway + i3 сессии. Cinnamon
  `mkForce false`, fbterm-tty2 `mkForce false`.
* **Сеть.** Только NFS-клиент (`pro.nfs.client.enable = true` →
  `desktop.local:/srv/nfs` в `/mnt/desktop`, autofs, 3-секундный
  таймаут). `headscale.enable = lib.mkForce false`.

## huawei — ноутбук, Intel iGPU, Haskell

* **Класс.** Intel-ноутбук, Wayland-leaning.
* **Загрузка.** systemd-boot (EFI), `canTouchEfiVariables = mkForce false`.
* **Kernel-параметры.** `mem_sleep_default=s2idle i915.enable_psr=0
  nvme_core.default_ps_latency_us=0 acpi_backlight=native`.
* **Modprobe.** `options snd-intel-dspcfg dsp_driver=1` — форсирует
  SOF-путь для Intel onboard-аудио.
* **Firmware.** `pkgs.sof-firmware` в `hardware.firmware`.
* **Хранилище.** `/` ext4, `/boot` vfat (EFI), swap на отдельном NVMe.
  `zramSlice.enable = true`.
* **GUI.** Только heavy-desktop (без `profile-exwm-minimal.nix`). Sway
  запускается вручную, не через EXWM-minimal glue.
* **Сеть.** NFS **выключен**: `desktop` на `192.168.1.x`, `huawei` на
  `192.168.34.x`, mDNS не пересекает подсети. Комментарий в
  `hosts/huawei/configuration.nix:60` — TODO re-enable после
  настройки headscale.
* **Haskell.** Импортирует `pro-haskell.nix` — `ghc`,
  `haskell-language-server`, `cabal-install`, `stack`, `ghcid`,
  `hlint`, `fourmolu`.
* **Composition.** Самый тяжёлый: `runtime + dev + exwm + lsp +
  privacy + media + tor + desktopHeavy + tor-browser`.

## vm — изолированная тестовая VM

* **Класс.** Single-purpose VM, без GUI.
* **Host-конструктор.** Собирается через `mkVmHost` в
  `flake.nix:92-102` (НЕ через `mkHost`). Минимальный baseline —
  `packages-runtime + tty-console + searxng + pro-users + pro-docker +
  pro-nfs + pro-spellcheck`. Нет импорта `configuration.nix`, поэтому
  `headscale.*` не является валидным атрибутом в этом eval.
* **Загрузка.** systemd-boot (EFI), `canTouchEfiVariables = mkForce false`.
* **Хранилище.** `/` на `/dev/sda1` (ext4). Без swap, без отдельного
  `/boot`.
* **Безопасность.** `security.sudo.wheelNeedsPassword = mkForce false`,
  `users.users.root.password = ""`. Это явно — комментарий в файле
  говорит «только для изолированной VM, в проде замените».
* **GUI.** `services.xserver.enable = mkForce false`,
  `services.displayManager.enable = mkForce false`.
* **Сеть.** `pro.nfs.client.enable = true` — VM может монитровать
  `desktop.local:/srv/nfs` для тестов.

## Порядок чтения

Если хотите понять историю host-quirk'ов целиком:

1. `modules/pro-hosts.nix` — реестр из четырёх строк.
2. `modules/host-policies.nix` — дефолты Tor, hardening SSH,
   per-host kernel-моды (huawei: bridges, cf19: iwlwifi).
3. `hosts/desktop/configuration.nix` — самый сложный из четырёх.
4. `hosts/cf19/configuration.nix` — dbus-regression override.
5. `flake.nix:104-109` — посмотрите, как четыре host-конфига
   подключаются к flake.
