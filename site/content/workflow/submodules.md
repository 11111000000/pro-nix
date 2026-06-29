+++
title = "Сабмодули"
template = "page.html"
weight = 3

[extra]
tldr = "11 сабмодулей, HTTPS по умолчанию, переключение just submodules-ssh. just switch не обновляет с remote, если не передан --update-submodules / sync. Хелпер-скрипт: scripts/sync-submodules.sh (sequential, таймауты)."

[[extra.next]]
title = "Агенты"
url = "/workflow/agents/"

[[extra.next]]
title = "Per-host чек-лист"
url = "/workflow/per-host/"
+++

# Сабмодули

Репозиторий подтягивает **11 git-сабмодулей** для Emacs-пакетов и
upstream-форков. Они настроены в `.gitmodules` с HTTPS-URL по
умолчанию; SSH — opt-in per host.

## 11 сабмодулей

| Имя | Путь | URL | Что |
|-----|------|-----|-----|
| `pro-tabs` | `submodules/pro-tabs` | github.com/gnu-emacs-ru/pro-tabs | Унифицированный Emacs tab-bar + tab-line с иконками |
| `carriage` | `submodules/carriage` | github.com/gnu-emacs-ru/carriage | «Вязальная машина для кода» для Org |
| `emcp` | `submodules/emcp` | codeberg.org/martenlienen/emcp | Emacs MCP-сервер (HTTP на 38913) |
| `telega.el` | `submodules/telega.el` | github.com/zevlg/telega.el | Telegram-клиент для Emacs (на TDLib) |
| `agent-shell` | `submodules/agent-shell` | github.com/11111000000/agent-shell | Emacs-shell для ACP-говорящих агентов |
| `acapella` | `submodules/acapella` | github.com/gnu-emacs-ru/acapella | A2A-протокол Emacs-клиент |
| `atlas` | `submodules/atlas` | github.com/gnu-emacs-ru/atlas | Универсальная карта проекта (формат APM v2) |
| `tao-theme` | `submodules/tao-theme` | github.com/11111000000/tao-theme-emacs | tao-yang (светлая) и tao-yin (тёмная) темы |
| `shaoline` | `submodules/shaoline` | github.com/11111000000/shaoline | Минималистичный mode-line |
| `agent-shell-hud` | `submodules/agent-shell-hud` | github.com/11111000000/agent-shell-hud | Многоязычный HUD-оверлей для agent-shell |
| `acp` | `submodules/acp` | github.com/xenodium/acp.el | Emacs-реализация Agent Client Protocol |

См. [Справочник → Сабмодули](reference/submodules.md) для полного
автогенерированного каталога.

## Политика HTTPS-по-умолчанию

В `.gitmodules` HTTPS-URL'ы повсюду. Это чтобы **кто угодно мог
клонировать без SSH-ключа** — включая CI-раннеры, контейнеры и
ad-hoc dev-окружения.

Trade-off: HTTPS-пользователи могут читать, но не могут пушить
в upstream-форки. Для пользователей с write-доступом
`just submodules-ssh` конвертирует все URL в SSH-форму.

## Политика сабмодулей во время `just switch`

`just switch <host>` запускает `scripts/helper-switch.sh`,
который реализует **трёхрежимную** политику:

| Режим | Когда | Что |
|-------|-------|-----|
| `init` | Любой сабмодуль не инициализирован (детектируется через `git submodule status \| grep '^-'`) | `git submodule update --init --recursive` |
| `skip` | Все сабмодули инициализированы | Использовать как есть. **Никакого fetch, merge, remote-касаний.** |
| `update` | Пользователь передал `update-submodules` или `sync` как `FLAGS`-аргумент | `scripts/sync-submodules.sh` (обновление с remote, sequential, с таймаутами) |

Default — `skip` — `just switch` **не** трогает сеть для
сабмодулей. Чтобы форсировать обновление, передайте флаг:

```bash
just switch huawei update-submodules
just switch cf19 sync
```

Чтобы пропустить политику полностью (escape hatch):

```bash
PRO_NIX_NO_SUBMODULE_UPDATE=1 just switch huawei
```

## Почему sequential, не parallel

`sync-submodules.sh` **не** использует `git submodule foreach` в
фоне. Запускается последовательно, с 20-секундным fetch-таймаутом
и 10-секундным merge-таймаутом на сабмодуль. Причина: parallel
fetch'и к GitHub'овскому anonymous API натыкаются на rate-limit в
течение минут. Sequential медленнее в worst case (165 с для 15
сабмодулей × 11 с каждый), но надёжен.

## Что происходит, когда fetch падает

`sync-submodules.sh` **не** валит сборку, когда fetch падает.
Логирует `WARNING: fetch failed for <submodule>`, пропускает
обновление этого сабмодуля и продолжает. Причина: Nix-рецепты
читают **локальный** `submodules/<name>`, не remote, так что
предыдущая валидная commit/submodule-пара остаётся собираемой.
Пользователь получает рабочую сборку, даже если один upstream down.

## Dirty-проверка сабмодуля

`sync-submodules.sh` делает dirty-проверку **до** любого fetch'а:

```bash
git submodule foreach 'git diff --quiet HEAD'
```

Если какой-то сабмодуль имеет незакоммиченные изменения, скрипт
громко падает. Это защищает от «я отредактировал сабмодуль, потом
запустил `just sync-submodules`, и скрипт затоптал мою работу» —
dirty-проверка заставляет пользователя сначала починить
загрязнённый сабмодуль.

## Ручные операции с сабмодулями

```bash
# Просто init
git submodule update --init --recursive

# Обновить один сабмодуль с remote
git submodule update --remote --merge submodules/agent-shell

# Обновить все сабмодули с remote
just sync-submodules
# или
git submodule update --remote --merge

# Переключить один сабмодуль на форк
git config submodule.submodules/agent-shell.url git@github.com:YOUR_USER/agent-shell.git
git submodule sync
```

## HTTPS → SSH

`just submodules-ssh` запускает `scripts/submodules-ssh.sh`. Скрипт:

1. Бэкапит `.gitmodules` в `.gitmodules.backup.<ts>`.
2. `trap EXIT` для восстановления при ошибке.
3. Читает URL каждого сабмодуля.
4. Для `github.com` URL конвертирует
   `https://github.com/<owner>/<repo>.git` в
   `git@github.com:<owner>/<repo>.git`.
5. Для `codeberg.org` URL конвертирует в
   `git@codeberg.org:<owner>/<repo>.git`.
6. Пишет новый URL через `git config -f .gitmodules`.
7. `git submodule sync --recursive` для обновления локального
   конфига.
8. `git submodule update --remote --merge` для фактического pull
   с нового URL.

Чтобы вернуться на HTTPS:

```bash
# Найти последний бэкап
ls -t .gitmodules.backup.* | head -1

# Восстановить
cp $(ls -t .gitmodules.backup.* | head -1) .gitmodules
git submodule sync
git submodule update --remote --merge
```

## Почему `git+file://$(pwd)?submodules=1` важен

`flake.nix` ссылается на все сабмодули через рецепты в
`nix/emacs-recipes/*.nix`. У каждого рецепта
`src = ../../submodules/<name>`. Когда `nix` вычисляет flake, он
захватывает source из локального пути — **но только если URL flake —
`git+file://...?submodules=1`**. Сокращения `path:` и `.` **не**
включают сабмодули в captured source, так что рецепты падают с
«path does not exist».

Поэтому каждый `just`-рецепт, который запускает `nix` (build,
switch, test, flake-check, check-all), использует явный URL. Скрипт
`helper-switch.sh` устанавливает его один раз в начале:

```bash
FLAKE_REF="git+file://$PWD?submodules=1"
```

`just`-рецепты, которым нужно установить его inline, делают так:

```bash
nix build ".#nixosConfigurations.cf19.config.system.build.toplevel"  # использует . → ПАДАЕТ для сабмодулей
nix build "git+file://$(pwd)?submodules=1#nixosConfigurations.cf19.config.system.build.toplevel"  # работает
```

`nix run .#check-all` — исключение; это `app`, и `program` — это
shell-скрипт, который устанавливает URL внутри. Рецепт живёт в
`flake.nix:137-146` и безопасен для вызова как `nix run .#check-all`.
