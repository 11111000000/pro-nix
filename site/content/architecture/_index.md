+++
title = "Архитектура"
sort_by = "weight"
template = "section.html"

[extra]
tldr = "Три слоя (NixOS / Emacs / агенты) с четырёхфазным бутстрапом в Emacs, flake с двумя host-конструкторами и трёхслойная сетевая модель (LAN mDNS + headscale mesh + SSH-нейминг)."
+++

Архитектуру лучше всего читать сверху вниз: из flake в модули, из
модулей в composition-файлы, из composition-файлов в host-конфиги.
Emacs — параллельный слой со своим четырёхфазным бутстрапом. Слой
агентов — тонкая обёртка шаблонов, которые деплоятся в `$HOME`.

## Nix flake

```nix
# flake.nix: упрощённо
inputs = {
  nixpkgs.url          = "nixpkgs/nixos-25.11";
  home-manager.url     = "github:nix-community/home-manager/release-25.11";
  opencodeBwrap.url    = "github:michalrus/opencode-bwrap-nix";
  pi.url               = "github:lukasl-dev/pi.nix";
  systems.url          = "github:nix-systems/default";
};

outputs = { ... }: {
  nixosConfigurations = {
    cf19    = mkHost [...];
    huawei  = mkHost [...];
    desktop = mkHost [...];
    vm      = mkVmHost [...];   # минимальный baseline, без configuration.nix
  };
  checks.${system}    = { default = huawei.config.system.build.toplevel; ... };
  apps.${system}      = { check-all = ...; site-serve = ...; site-regen = ...; };
  devShells.${system} = { default = ...; };  # с emacs-pro wrapper
  packages.${system}  = { site = ...; };
};
```

Два host-конструктора:

* `mkHost` — полный: `configuration.nix` + `modules/searxng.nix` +
  глобальные (`pi.nixosModules.default`, `modules/ssh-agent.nix`) +
  per-host.
* `mkVmHost` — минимальный: `packages-runtime.nix` + `tty-console.nix`
  + `searxng.nix` + per-host. Без `configuration.nix`. Поэтому
  `headscale.enable` не существует в eval `vm`.

## Дерево NixOS-модулей

50+ файлов в `modules/`, сгруппированы по роли:

| Паттерн | Что это | Пример |
|---------|---------|--------|
| `pro-*.nix` | Обычные NixOS-модули | `pro-network.nix`, `pro-ssh-clients.nix`, `pro-emacs-rescue.nix` |
| `session-*.nix` | WM / DM | `session-i3.nix`, `session-sway.nix`, `session-cinnamon.nix` |
| `system-*.nix` | Низкоуровневые политики | `system-boot.nix` (kernel, GRUB) |
| `system-package-sets-*.nix` | **НЕ модули** — функции `{ pkgs }: { fooPackages = [ … ]; }`, импортируются из `hosts/*/composition.nix` | `system-package-sets-runtime.nix`, `system-package-sets-exwm.nix` |
| `nix-*.nix` | Кастомные пакеты / юниты (overlays) | `nix-cuda-compat.nix` (только overlay) |

Composition-файлы — это трюк. Хост — не модуль; это набор
`environment.systemPackages` плюс несколько маркеров `mkDefault true`.
См. `hosts/desktop/composition.nix:1-16` для примера desktop.

## Emacs-бутстрап

Четыре фазы, в каждой свой файл:

| Фаза | Файл | Что делает |
|------|------|------------|
| 1 | `early-init.el` | До запуска package-системы: базовые переменные package, load-path, GUI-hygiene, best-effort treesit |
| 2 | `init.el` | Главная загрузка: `user-emacs-directory`, `custom-file`, грузит `pro-compat`/`pro-packages`, вызывает `pro-emacs-base-start` |
| 3 | `site-init.el` | Манифест модулей + резолвер + загрузчик ключей + `provided-packages.el` (факты от Nix) |
| 4 | `pro-emacs-base-start` | Грузит все 64 модуля, затем `pro-keys-apply-pending` |

**Контракт soft-reload** живёт в `pro-reload.el`:

```elisp
;; Авторы модулей регистрируют teardown на pro--after-reload-hook
(pro/after-reload #'my-reset-fn)

;; C-x M-c     (или M-x pro/reload-config)   reload в месте
;; C-u M-x pro/reload-config                re-evals site-init.el + все модули
```

Контракт описан в шапке файла (`emacs/base/modules/pro-reload.el:11-22`):
top-level формы должны быть идемпотентны, модули с persistent state
должны пересоздавать его на `pro--after-reload-hook`.

## Трёхслойная сеть

| Слой | Модуль | Транспорт | Scope |
|------|--------|-----------|-------|
| **LAN mDNS** | `pro-network.nix` (Avahi + nss-mdns) + `pro-peer.nix` (публикует `_ssh._tcp`) | UDP 5353 multicast | Один L2-сегмент |
| **Mesh** | `headscale.nix` (control plane) + будущий `pro-tailnet.nix` (клиенты) | WireGuard | Где есть интернет |
| **SSH-нейминг** | `pro-ssh-clients.nix` (генерит `ssh_config.d/pro.conf`) | SSH поверх того кандидата, что ответит | Всегда (что ответит первым) |

SSH-слой — единственный с настоящим фолбэком. `pro-ssh-clients.nix`
генерит один `Host`-блок на каждый хост в `pro.hosts` с кандидатами
в порядке: `tailnet-fqdn` → `tailnet-short` → `<name>.local` → `addr` →
`onion` (через torsocks). Первый доступный выигрывает. У каждого
кандидата свой `ConnectTimeout`, поэтому мёртвый `.local` не
блокирует рабочий tailnet-FQDN.

## Стек агентов

```
$HOME/.pi/agent/         (деплоится pro-agent-configs.nix)
├── settings.json         # defaultProvider, defaultModel, npm-пакеты
├── models.json           # 3 провайдера × 31 модель
├── mcp.json              # emcp + chrome-devtools
├── skills/emacs-emcp/    # SKILL.md (operator guide для emcp)
├── skills/safe-bash/     # SKILL.md (cross-platform shell safety)
└── extensions/pi-permission-system/config.json   # deny-by-pattern

$HOME/.config/opencode/
├── opencode.json         # те же 3 провайдера
├── tui.json              # plugin: []
└── skills/emacs-emcp/SKILL.md

$HOME/.local/share/pro-nix/load-agent-env.sh
    читает ~/.authinfo, экспортит {AITUNNEL,OPENROUTER,OPENAI,MISTRAL,MINIMAX,DEEPSEEK}_KEY
```

MCP-инструменты агенту доступны двумя способами:
- В **pi**: через прокси-тулзу `mcp({tool: ..., args: ...})`
- В **opencode**: как прямые тулы, например `emcp_apropos`

`emacs-emcp` skill — это один и тот же Markdown в обоих местах, с
единственным отличием — наличием YAML frontmatter (у `pi` есть, у
`opencode` нет).

## Резюме

Три независимых слоя, у каждого — единственный источник правды:

* **Nix** — flake → модули → composition → хост.
* **Emacs** — early-init → init → site-init → pro-emacs-base-start.
  **64 модуля `pro-*.el`** загружаются по умолчанию.
* **Агенты** — `local-templates/` →
  `home.activation.pro-agent-configs-deploy` → `~/.pi/agent/`,
  `~/.config/opencode/`, плюс
  `~/.local/share/pro-nix/load-agent-env.sh`.

Этот сайт — сам по себе четвёртый слой, тоже декларативный: исходник
в `site/`, сборка через `nix build '.#site'`, деплой GitHub Actions на
`gh-pages` и `surge.sh`.
