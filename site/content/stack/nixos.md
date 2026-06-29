+++
title = "Слой NixOS"
template = "page.html"
weight = 1

[extra]
tldr = "Системный слой. NixOS 25.11 запинен, 5 overlays, 50+ модулей, дисциплина mkDefault vs mkForce, composition-файлы, без ручных post-install шагов после just switch."

[[extra.next]]
title = "Слой Emacs"
url = "/stack/emacs/"

[[extra.next]]
title = "Flake inputs"
url = "/architecture/flake/"
+++

# Слой NixOS

Системный слой — чистый NixOS. Без побочного package-менеджмента,
без руками-писанных файлов в `/etc/`, без `apt-get install` для
системных пакетов. Всё — либо NixOS-опция, либо кастомный модуль в
`modules/`, либо пакет, подтянутый через `nix/overlays/`.

## Pin

`nixpkgs/nixos-25.11` в `flake.nix:6`. `home-manager/release-25.11`
follows nixpkgs.

URL flake **должен** быть `git+file://$(pwd)?submodules=1` для
`nix flake check`, `nix build` и `nixos-rebuild`. Сокращения `path:`
и `.` **не** включают сабмодули в captured source, а Emacs-рецепты
читают `../../submodules/<name>` как source.

## Overlays

| Overlay | Что добавляет |
|---------|---------------|
| `emacs-extra.nix` | ~15 Emacs-рецептов (pro-tabs, telega, emcp, http-server, agent-shell, …) и внешние MELPA-пакеты (embark, eldoc-box) |
| `opencode-stub.nix` | `opencode` v1.15.10 из npm, patchelf'нут под glibc |
| `pi-acp.nix` | `piAcp` (`nix/node-packages/pi-acp.nix`) |
| `mirrors.nix` | URL-rewriter для `curl.haxx.se`, `astron.com`, `git.kernel.org` |
| `github-proxy.nix` | Опц. `NIX_GITHUB_PROXY` (env) |

`pkgsOverlay = import nixpkgs { overlays = [...]; }` — **единственный**
способ применения overlays. Хост-специфичных overlays нет.

## Модули

См. [Справочник → NixOS-опции](reference/options.md) для 6 модулей,
которые объявляют `mkOption`. Остальные — модули без опций, чистая
политика.

Composition-файлы (`system-package-sets-*.nix`) — **не** NixOS-модули.
Это функции `{ pkgs }: { somePackages = [ … ]; }`, которые импортируются
из `hosts/*/composition.nix` и `++`дятся в `environment.systemPackages`.

## Build / switch

```bash
nix build ".#nixosConfigurations.<host>.config.system.build.toplevel"
nix build ".#nixosConfigurations.{cf19,desktop,vm}.config.system.build.toplevel"
nix run .#check-all    # три полных хоста одной командой
```

Медленные VM-тесты гейтнуты `PRO_NIX_RUN_SLOW_CHECKS=1` — они
дорогие (полная загрузка/активация NixOS VM) и по умолчанию не
запускаются.

## Чек-лист «после switch»

`nixos-rebuild switch` активирует систему, но **не**:

* деплоит `local-templates/{pi,opencode}/*` (используйте
  `just deploy-agents` или `just switch-with-agents`);
* устанавливает npm-пакеты `pi` (используйте
  `just install-pi-packages`);
* восстанавливает SSH-ключи (запустите `ssh-copy-id` per host);
* поднимает `tor`-сервис на хосте, где нужен hidden service.

См. [Рабочий процесс → Per-host чек-лист](workflow/per-host.md)
для полной таблицы.
