+++
title = "Что такое pro-nix"
sort_by = "weight"
template = "section.html"

[extra]
tldr = "Один репо, один пользователь, четыре машины, один редактор, одна клавиатурная раскладка — и прозрачный свод правил для каждого решения в стеке."
+++

pro-nix — это **декларативная, переносимая конфигурация NixOS + Emacs +
AI-агенты**, которая работает на четырёх физических машинах
(`desktop`, `cf19`, `huawei`, `vm`) одного пользователя, без
ручных шагов после начального `just switch`. Стек намеренно
opinionated: когда есть выбор между «гибко» и «предсказуемо»,
pro-nix выбирает предсказуемо.

Кодовая база — единственный источник правды для системы, редактора
и слоя агентов. Тот же репо устанавливает NixOS, настраивает Emacs
с 64 модулями, поднимает `pi` и `opencode` для AI-работы, разворачивает
приватный mesh через `headscale`, прокладывает tmux/Tor-фолбэк для
SSH и обслуживает локальный поиск через `SearXNG`.

## Что pro-nix **является**

* **Рабочий NixOS-сетап.** Загружается, уходит в suspend,
  переживает `nixos-rebuild switch`.
* **Профиль Emacs.** Buffer banner, вертикальное completion,
  project-wide ripgrep, TUI для контейнеров, Telegram на TDLib,
  agent shells, MCP-инструменты.
* **Сеть из 4 хостов**, которые находят друг друга через LAN
  (`<host>.local`), через приватный mesh
  (`<host>.<base-domain>` через headscale) и через Tor
  (`<host>-onion` через torsocks) — что ответит первым.
* **Свод правил.** `AGENTS.md` и шапки модулей описывают инварианты;
  `tests/contract/*` поддерживает их на каждом CI-прогоне.

## Чего pro-nix **не** делает

* **Не дистрибутив.** Это окружение одного пользователя,
  copy-paste friendly, но не для пере-распространения.
* **Не учебник.** Предполагается, что вы знаете синтаксис Nix;
  сайт объясняет **почему** и указывает **где**, а не **как учить
  Nix**.
* **Не starter template.** Никакого «fork me and rename». Хосты
  в `modules/pro-hosts.nix` реальные, UUID в `hosts/*/configuration.nix`
  реальные, раскладки в `conf/*-config.in` реальные.
* **Не community project.** Принадлежит, редактируется и
  эксплуатируется одним человеком; публичное зеркало делится
  паттернами, а не координирует контрибьюторов.

## Устройство репозитория

```
configuration.nix          # корневой NixOS-конфиг
flake.nix                  # 4 хоста, 5 overlays, 17 devShell-пакетов
modules/                   # 50+ NixOS-модулей + composition-файлы
hosts/<name>/              # 4 host-конфига (по каталогу на машину)
emacs/base/                # init.el + 64 pro-*.el модуля
emacs-keys.org             # таблица глобальных клавиш (исполняемый код)
nix/                       # overlays, recipes, node-packages
local-templates/           # source of truth для AI-агентских конфигов
conf/                      # Xresources, sway/i3, dunstrc, qt5ct
scripts/                   # 80+ shell-утилит
tests/                     # 4 категории (vm / contract / scenario / gui)
tools/                     # holo-verify, surface-lint, mkforce-lint
submodules/                # 11 git-сабмодулей (Emacs-пакеты)
```

## Публичная поверхность

Этот сайт генерируется из того же исходного кода через
[Zola](https://www.getzola.org/), обёрнутого в Nix-деривацию. Страницы
под **Справочником** автогенерируются чтением файлов; если источник
двигается — сайт двигается вместе. См. [Архитектура](architecture/_index.md)
и [Соглашения](conventions/_index.md) для того, как устроена
генерация.
