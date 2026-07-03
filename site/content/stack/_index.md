+++
title = "Стек"
sort_by = "weight"
template = "section.html"

[extra]
tldr = "NixOS 25.11 (pin), Emacs 30, pi + opencode + EMCP, EXWM + Sway + i3, Tor + headscale. Все версии запинены, все выборы видны."
+++

Стек — это то, что получается, если взять «мне нужна переносимая
рабочая станция» как строгое требование и начать рисовать граф
зависимостей.

## Слой 1: NixOS 25.11

Система — NixOS, запинена на `nixos-25.11` в `flake.nix`. Flake
приносит `home-manager/release-25.11` (тоже запинен),
`opencode-bwrap-nix` (`michalrus`) и `pi.nix` (`lukasl-dev`).

**5 overlays:**

| Overlay | Что добавляет |
|---------|---------------|
| `nix/overlays/emacs-extra.nix` | ~15 Emacs-рецептов (pro-tabs, telega, emcp, http-server, agent-shell, …) + внешние MELPA-пакеты (embark, eldoc-box) |
| `nix/overlays/opencode-stub.nix` | `opencode` из npm, patchelf'нут под glibc |
| `nix/overlays/pi-acp.nix` | `piAcp` из `nix/node-packages/pi-acp.nix` |
| `nix/overlays/mirrors.nix` | URL-rewriter для `curl.haxx.se`, `astron.com`, `git.kernel.org` |
| `nix/overlays/github-proxy.nix` | Опциональный `NIX_GITHUB_PROXY` |

## Слой 2: Emacs 30 (из Nix)

`emacsPkg = pkgs.emacs30 or pkgs.emacs` — предпочтение Emacs 30.
Список provided-пакетов (см. [Стек → Emacs](stack/emacs.md)) живёт
в `emacs/core.nix#pro.emacs.providedPackages` и содержит **58 пакетов**.
Они становятся видны Emacs через `EMACSLOADPATH` (вычисляется в
build-time обходом всех `share/emacs/site-lisp` в closure).

## Слой 3: AI-агенты

* **`pi`** — основной CLI-агент, из `lukasl-dev/pi.nix`. Его NixOS-модуль
  (`pi.nixosModules.default`) подключён глобально.
* **`opencode`** — npm-бинарь, пробрасывается через `opencode-stub`
  overlay. Sandbox-вариант через `opencode-bwrap-nix` (Home Manager
  module).
* **`pi-acp`** — `svkozak/pi-acp` v0.0.27 — адаптер от `pi` к Agent
  Client Protocol. Собирается через `buildNpmPackage` + Node 20.
* **`emcp`** — мост от Emacs к MCP. HTTP-сервер живёт на
  `127.0.0.1:38913`. Emacs-пакет — форк `codeberg.org/martenlienen/emcp`;
  HTTP-бэкенд — форк его же `http-server.el`.
* **`gptel`** — Emacs-сторона LLM-клиента. Бэкенды объявлены в
  `emacs/base/modules/ai-models.json` (3 провайдера: openrouter,
  siliconflow, aitunnel + пользовательские override'ы).

## Слой 4: Оконные менеджеры — три, одна клавиатура

Клавиатурная раскладка одинакова во всех трёх:

| Действие | EXWM | Sway | i3 |
|----------|------|------|-----|
| Фокус окна | `s-h` / `s-j` / `s-k` / `s-l` | `Mod4+h/j/k/l` | `Mod4+h/j/k/l` |
| Переместить окно | `s-H` / `s-J` / `s-K` / `s-L` | `Mod4+Shift+h/j/k/l` | `Mod4+Shift+h/j/k/l` |
| Рабочий стол 1..9 | `s-1`..`s-9` | `Mod4+1`..`Mod4+9` | `Mod4+1`..`Mod4+9` |
| Терминал | `C-c t o` (Emacs vterm) | `Mod4+Return` (foot) | `Mod4+Return` (xterm) |
| Запуск приложения | `s-x` (Emacs consult) | `Mod4+Space` (wofi) | `Mod4+Space` (dmenu) |
| Закрыть окно | `C-x k 0` | `Mod4+q` | `Mod4+q` |
| Перезагрузить конфиг | `C-x M-c` | `Mod4+Shift+c` | `Mod4+Shift+c` |

EXWM-session launcher — в `emacs/exwm.nix:96-176`. Делает
`ssh-agent`, `xset b off`, `xhost +SI:localuser:$USER`, IME-env,
`xrdb -merge`, `systemd-run --user --scope -p MemoryMax=2G -p CPUQuota=120%`
и `exec emacs`. Лог пишется в `~/.cache/emacs-startup/gdm-exwm.log`.

## Слой 5: Приватность и Tor

* `tor` (локальный сервис, SOCKS5 на 9050, control 9051, DNS 9053)
* `torsocks`, `obfs4`, `meek`, `snowflake` (через
  `pro-privacy.nix` ClientTransportPlugin)
* `onionshare`, `nyx`, `dnscrypt-proxy`, `proxychains`, `mullvad-vpn`
* Опц.: `i2p` (выключен по умолчанию), `yggdrasil` mesh daemon
* `scripts/pro-tor` переключает `~/.config/pro-tor/env` (mode 0700),
  который экспортирует `ALL_PROXY=socks5h://…`,
  `NO_PROXY=127.0.0.1,localhost,*.local,.local,::1`

## Слой 6: Инструменты разработчика

* LSP: `pyright`, `jdtls`, `rust-analyzer`, `gopls`,
  `bash-language-server`
* Haskell: `ghc`, `haskell-language-server`, `cabal-install`,
  `stack`, `ghcid`, `hlint`, `fourmolu` (см. `modules/pro-haskell.nix`)
* Docker: `lazydocker`, `dive`, `ctop`, `trivy`, `hadolint`, `sops`,
  `age`, плюс кастомный мост `pro-dev` (`172.20.0.0/16`) в
  `modules/pro-docker.nix`
* Шаблоны: `templates/microservice/` (alpine + tini + SOPS + just
  рецепты)

## 8 composition-файлов (`system-package-sets-*.nix`)

| Файл | Назначение |
|------|-----------|
| `runtime` | базовый рантайм, все хосты |
| `dev` | dev-toolchain, `huawei` |
| `exwm` | X11/EXWM-хелперы, `huawei`/`vm` |
| `desktop-heavy` | chromium, firefox, telegram, …, `desktop`/`huawei` |
| `lsp` | LSP-серверы, `huawei` |
| `media` | ffmpeg, mpv, `huawei` |
| `privacy` | tor, snowflake, dnscrypt-proxy, mullvad-vpn, `huawei`/`vm` |
| `tor` (lightweight control) | `pro-tor`, `torwrap`, torsocks — каждый хост |

`tor` и `privacy` — opt-in: `huawei` и `vm` несут `privacy`; каждый
хост несёт `tor` (через lightweight `pro-tor` CLI).

## Версии и пины

| Компонент | Версия | Где |
|-----------|---------|-----|
| NixOS | `nixos-25.11` | `flake.nix#inputs.nixpkgs.url` |
| home-manager | `release-25.11` | `flake.nix#inputs.home-manager.url` |
| Linux kernel | `linuxPackages_6_6` (по умолчанию) / `linuxPackages_latest` (desktop) | `configuration.nix`, `hosts/desktop/configuration.nix:26` |
| Emacs | 30 (предпочтительно) | `flake.nix:56` |
| pi | (upstream запинен) | `flake.nix#inputs.pi.url` |
| opencode | 1.17.13 | `nix/overlays/opencode-stub.nix` |
| telega | 0.8.632 | `nix/emacs-recipes/telega.nix` |
| emcp | unstable-2026-06-11 | `nix/emacs-recipes/emcp.nix` |
| pi-acp | 0.0.27 | `nix/node-packages/pi-acp.nix` |
| tree-sitter grammars | 0.13.49 | `nix/treesitter-grammars.nix` |
