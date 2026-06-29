+++
title = "NixOS-модули"
template = "page.html"
weight = 2

[extra]
tldr = "50+ файлов в modules/ по 5 паттернам: pro-*, session-*, system-*, system-package-sets-* (НЕ модули), nix-*."

[[extra.next]]
title = "Composition-файлы"
url = "/architecture/composition/"

[[extra.next]]
title = "Справочник опций"
url = "/reference/options/"
+++

# NixOS-модули

`modules/` шире, чем предполагает имя. Там **пять** паттернов
файлов, у каждого своя роль.

## Пять паттернов

| Паттерн | Роль | Как удалить |
|---------|------|-------------|
| `modules/pro-*.nix` | Обычные NixOS-модули | Убрать из `imports` в `configuration.nix` или `hosts/*/configuration.nix` |
| `modules/session-*.nix` | WM / DM | То же |
| `modules/system-*.nix` | Низкоуровневые политики (boot, systemd) | Стандартное удаление из `imports` |
| `modules/system-package-sets-*.nix` | **НЕ NixOS-модули** — функции `{ pkgs }: { somePackages = [ … ]; }`, импортируются из `hosts/*/composition.nix` | Удалить файл + `import` + `++ X.somePackages` в **обоих** `hosts/*/composition.nix` |
| `modules/nix-*.nix` | Кастомные пакеты / юниты (overlays, derivations) | Стандартное удаление из `imports` (или убрать из `overlays = [...]` в `flake.nix`, если это overlay) |

## Указатель 50+ модулей

### Сеть (главный слой)

* `pro-hosts.nix` — реестр хостов. `pro.hosts.<name> = { sshUser, roles,
  tailnet, onion, addr, tags }`.
* `pro-network.nix` — Avahi + nss-mdns, mDNS-порт, LAN-gateway IP
  forwarding.
* `pro-ssh-clients.nix` — генерит `/etc/ssh/ssh_config.d/pro.conf` с
  одним `Host`-блоком на зарегистрированный хост.
* `headscale.nix` — control plane для WireGuard mesh. Опции
  `headscale.*`.
* `pro-peer.nix` — Avahi-публикация, SSH-hardening, опц. GPG key
  sync, опц. Tor hidden service, опц. Yggdrasil / WireGuard.
* `host-policies.nix` — host-условные политики (Tor default на
  всех, snowflake на huawei, iwlwifi power-save на cf19).
* `pro-nfs.nix` — NFSv4 server/client. Взаимоисключающие на одном
  хосте.
* `pro-storage.nix` — Samba (с `pro-samba-setup-users` oneshot) +
  Syncthing + private/public shares.
* `pro-smb-automount.nix`, `pro-samba-keys-sync.nix`,
  `pro-user-automount.nix` — system/user automount-шаблоны +
  decrypt-on-demand.
* `pro-privacy.nix` — Tor + obfs4 + meek + snowflake
  ClientTransportPlugin, i2p, dnscrypt-proxy, mullvad, nyx,
  onionshare, proxychains.
* `searxng.nix` — самохост SearXNG (сейчас `lib.mkForce false` на
  верхнем уровне из-за бага settings.yml).

### Пользователи и права

* `pro-users.nix` — 4 Unix-пользователя (`az, za, la, bo`), группы
  (`networkmanager`, `wheel`, `bluetooth`, `docker`, `input`,
  `uinput`, `pro`, `pro-agent`), NOPASSWD sudo, umask 0002.
* `pro-users-nixos.nix` — Home Manager для pro-пользователей.
  Длинный список provided Emacs-пакетов, мост к `pro.emacs.*`.
* `pro-users-termux.nix` — Home Manager для Termux (Android), без
  GUI.
* `pro-home-perms.nix` — per-user activation, chown'ит защищённые
  директории.
* `ssh-agent.nix` — per-user systemd `ssh-agent` с
  `%t/ssh-agent.socket`, env-скрипт в `/etc/profile.d/ssh-agent.sh`.

### Система и железо

* `system-boot.nix` — GRUB default `nodev`, EFI touch defaults,
  plymouth spinner, `linuxPackages_6_6`, sysrq=1.
* `tty-console.nix` — `console.useXkbConfig = true`,
  `LatArCyrHeb-16.psfu.gz`, `SYSTEMD_VCONSOLE_FORCE=1`, gpm, kbdrate.
* `nix-cuda-compat.nix` — overlay: `types.atom` в formats,
  `cudaPackages.{cudaFlags, cudaVersion}`.
* `zram-slice.nix` — `systemd.services.enable-zram` oneshot.
  `size = "auto"` = 50% RAM, cap 16384 MB.
* `packages-runtime.nix` — минимальный runtime: bashInteractive,
  openssh, python3, dbus, gawk, kbd, mc, emacs, rxvt-unicode,
  curl/wget, jq, just, git, gh, ripgrep, fd, tmux, tree, htop, lsof,
  alsa-utils, beep.
* `fbterm-tty.nix` — fbterm на tty2. По умолчанию выключен; хосты
  подключают.
* `pro-power-beep.nix` — двухуровневый low-battery beep. PC speaker
  → BEL → ALSA. C5-E5-G5 warning, A5-A5-A5-C6 urgent.
* `pro-wifi-watchdog.nix` — периодический `nmcli connection up`,
  если target IP недоступен. Выключен, когда NetworkManager off.
* `pro-emacs-rescue.nix` — `Control+Alt+Shift+r` → xbindkeys grab →
  emacsclient probe → poke зависший `*package*` → `kill -USR2` →
  `systemd-run --user --scope` restart.
* `zram-slice.nix` — см. выше.

### Сессия / отображение

* `session-base.nix` — LightDM, xkb `us,ru
  ctrl:nocaps,grp:toggle,grp_led:caps`.
* `session-i3.nix` — i3 + polybar (использует `conf/i3-config.in`).
* `session-sway.nix` — Sway + waybar/mako/swaybg/swaylock/swayidle/
  wl-clipboard/wofi/foot/grim/slurp (использует `conf/sway-config.in`).
* `session-cinnamon.nix` — Cinnamon (тяжёлый).
* `session-fonts.nix` — font-пакеты + `conf/fonts.conf`,
  `conf/gtk-*/settings.ini`, `conf/qt*ct.conf`, `conf/kdeglobals`,
  `conf/Xresources`, `conf/dunstrc`.
* `session-audio.nix` — PipeWire (pulse + alsa + wireplumber),
  rtkit, ALSA persistence.
* `pro-desktop.nix` — обёртка: session-base + session-fonts +
  session-audio + session-cinnamon + firefox.
* `pro-exwm-desktop.nix` — EXWM GUI-слой (feh, scrot, dunst,
  flameshot, mpv, …).
* `pro-heavy-desktop.nix` — тяжёлый: chromium, telegram-desktop,
  element-desktop, jami, weechat, ffmpegthumbnailer.
* `profile-exwm-minimal.nix` — `pro.profiles.exwmMinimal.enable` →
  EXWM windowManager + gdm=false + cinnamon=false + per-host
  sessionCommands.
* `pro-profiles.nix` — объявляет `pro.profiles` как submodule с
  пустыми опциями, чтобы другие модули могли добавлять nested-опции.

### Dev / build / Docker

* `pro-dev.nix` — dev-toolchain (direnv, shellcheck, shfmt, bat,
  tldr, pipx, nodejs_20, esbuild, prettier,
  typescript-language-server, rust-analyzer, bash-language-server,
  cmake, gcc, clang, ag, pt, fzf, lnav, mosh, pandoc, graphviz,
  plantuml, mermaid-cli, eldev, cask, lazydocker, dive, ctop, trivy,
  hadolint, sops, age).
* `pro-haskell.nix` — ghc, haskell-language-server, cabal-install,
  stack, ghcid, hlint, fourmolu.
* `pro-docker.nix` — `virtualisation.docker.enable = true` + oneshot
  `docker-network-pro-dev` создаёт мост `pro-dev` (172.20.0.0/16 gw .1).
* `pro-spellcheck.nix` — vendored ru_RU hunspell из
  LibreOffice/dictionaries (MPL-2.0), обёрнут через `makeWrapper` с
  `DICPATH` вкомпиленным.
* `opencode-tui.nix` — `pro.opencode.tui.enable` → пишет
  `~/.config/opencode/tui.json`.
* `pro-agent-configs.nix` — `home.activation.pro-agent-configs-deploy`
  деплоит `local-templates/{pi,opencode}/*` в `$HOME` с
  `copy_if_missing`; идемпотентный `~/.profile` маркер.

### Composition-файлы (функции, не модули)

Это **не** NixOS-модули. Это `{ pkgs }: { somePackages = [ … ]; }`
функции, импортируемые из `hosts/*/composition.nix`.

* `system-package-sets-runtime.nix` — `runtimePackages`.
* `system-package-sets-dev.nix` — `devPackages` + `llmLabCmd` +
  `pythonCmd`.
* `system-package-sets-exwm.nix` — `exwmPackages`.
* `system-package-sets-desktop-heavy.nix` — `desktopHeavyPackages`
  (chromium, firefox, telegram, element, jami, steam, dunst,
  flameshot, copyq, pavucontrol, ffmpeg-full, deluge) плюс
  `chromium` и `firefox` обёртки с `systemd-run --user --scope -p
  MemoryMax=... -p CPUQuota=...`.
* `system-package-sets-lsp.nix` — `lspPackages` (pyright, jdtls,
  rust-analyzer, gopls, bash-language-server) с `maybe = pkg: if
  pkg == null then [] else [pkg]` гардами.
* `system-package-sets-media.nix` — `mediaPackages` (ffmpeg-full,
  mpv, ffmpegthumbnailer).
* `system-package-sets-privacy.nix` — `privacyPackages` (tor,
  torsocks, obfs4, snowflake, nyx, onionshare, dnscrypt-proxy,
  wireguard-tools, yggdrasil, i2p, proxychains, mullvad-vpn,
  tor-browser).
* `system-package-sets-tor.nix` — `torControlPackages`
  (lightweight CLI: `pro-tor`, `torwrap`).
* `system-package-sets-lsp.nix` — см. выше.

## Как хост выбирает composition-файлы

`hosts/cf19/composition.nix` (минимальный):

```nix
{ lib, pkgs, ... }:
let
  tor = import ../../modules/system-package-sets-tor.nix { inherit pkgs; };
in
{
  pro.profiles.exwmMinimal.enable = lib.mkDefault true;
  environment.systemPackages = tor.torControlPackages;
}
```

`hosts/huawei/composition.nix` (самый тяжёлый):

```nix
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
```

`hosts/vm/composition.nix`:

```nix
environment.systemPackages = with pkgs;
  runtime.runtimePackages
  ++ dev.devPackages
  ++ exwm.exwmPackages
  ++ privacy.privacyPackages
  ++ tor.torControlPackages
  ++ [ gh tor-browser ];
```

`hosts/desktop/composition.nix` (средний):

```nix
environment.systemPackages = tor.torControlPackages ++ (with pkgs; [ ... ]);
```

Форма: выбери composition-файлы под роль хоста, `++` их, добавь
хост-специфичные пакеты в конце.

## Детекция в тулзах

`tools/surface-lint.sh` (с `--check-style`) требует, чтобы каждый
`modules/*.nix` имел пятисекционную шапку (Назначение / Цель /
Контракт / Побочные эффекты / Proof). Также проверяет наличие
кириллицы — конвенция проекта писать шапку на русском.

`tools/holo-verify.sh unit` запускает 10 unit-тестов из
`tests/contract/unit/`.
