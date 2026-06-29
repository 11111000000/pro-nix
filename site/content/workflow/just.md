+++
title = "just-рецепты"
template = "page.html"
weight = 2

[extra]
tldr = "30+ just-рецептов в 5 кластерах: build/switch, сабмодули, агенты, тесты, Docker. Все используют git+file://...?submodules=1."

[[extra.next]]
title = "Сабмодули"
url = "/workflow/submodules/"

[[extra.next]]
title = "Soft-reload"
url = "/workflow/reload/"
+++

# just-рецепты

`justfile` — **каноническая поверхность команд**. ~30 рецептов в
пяти кластерах. Ниже — полный список с тем, что каждый делает и
когда использовать.

## Кластер 1: build / switch

| Рецепт | Команда | Когда |
|--------|---------|------|
| `just build <host>` | `sudo nixos-rebuild build --flake "git+file://$(pwd)?submodules=1#{{HOST}}"` | Только сборка, без применения. Используйте для валидации правки. |
| `just switch <host>` | `scripts/switch.sh "{{HOST}}"` | Применить. Самая частая команда. Запускает `helper-switch.sh`. |
| `just switch <host> update-submodules` | То же + флаг `update-submodules` | Обновить сабмодули с remote перед сборкой. |
| `just switch <host> sync` | То же + флаг `sync` | Алиас для `update-submodules`. |
| `just test <host>` | `sudo nixos-rebuild test --flake "git+file://$(pwd)?submodules=1#{{HOST}}"` | Применить на время следующей загрузки, затем откатить. Безопаснее, чем `switch`, для рискованных правок. |
| `just flake-check` | `nix flake check "git+file://$(pwd)?submodules=1"` | Синтаксис + проверка типов. Быстрый (~30 с). |
| `just check-all` | `nix run .#check-all` | Собрать 3 полных хоста. Медленно (10-30 мин). |
| `just check-fast` | `./tools/holo-verify.sh --help >/dev/null` | Sanity-check что `holo-verify` запускается. |
| `just check-docs` | `./tools/holo-verify.sh --help >/dev/null` | То же (плейсхолдер для будущей docs-only проверки). |
| `just check-elisp` | `./tools/holo-verify.sh elisp` | Все `pro-*.el`-модули парсятся и загружаются. |

## Кластер 2: сабмодули

| Рецепт | Команда | Когда |
|--------|---------|------|
| `just sync-submodules` | `scripts/sync-submodules.sh` | Обновить все сабмодули с remote. Sequential (15 сабмодулей × ~11 с). |
| `just submodules-ssh` | `scripts/submodules-ssh.sh` | Конвертировать все HTTPS-URL сабмодулей в SSH. Используйте, если есть write-доступ. |
| `PRO_NIX_NO_SUBMODULE_UPDATE=1 just switch <host>` | Escape hatch | Пропустить политику сабмодулей полностью. |

`just switch` сам **не** обновляет сабмодули с remote по
умолчанию. Он инициализирует их только если они не инициализированы.
Если хотите обновление — используйте флаг `update-submodules`.

## Кластер 3: агенты

| Рецепт | Команда | Когда |
|--------|---------|------|
| `just deploy-agents` | `scripts/deploy-agent-configs.sh && scripts/install-pi-packages.sh` | Задеплоить шаблоны + npm-пакеты. Без `nixos-rebuild`. |
| `just install-pi-packages` | `scripts/install-pi-packages.sh` | Только npm-пакеты. |
| `just switch-with-agents <host>` | deploy + install + switch, по порядку | Полный цикл. Используйте на свежей машине. |
| `just update-pi-version` | `scripts/update-pi-version.sh` | Bump входа `pi` в `flake.lock`. Dry-run по умолчанию. |

`deploy-agents.sh` — `copy_if_missing` — безопасно запускать
многократно. Чтобы форсировать re-deploy конкретного файла —
`rm` его сначала, затем запустите скрипт.

## Кластер 4: тесты

| Рецепт | Команда | Когда |
|--------|---------|------|
| `just headless-tty` | `./scripts/emacs-verify.sh tty` | TTY headless smoke. |
| `just headless-xorg` | `./scripts/emacs-verify.sh xorg` | Xvfb headless smoke. |
| `just headless` | `./scripts/emacs-verify.sh both` | Оба. |
| `just headless-tests` | `./scripts/test-emacs-headless.sh both` | Полный headless ERT-набор. |
| `just headless-parse` | `./scripts/parse-emacs-logs.sh` | Pretty-print последних `*test*` / `[pro-emacs]` / ERT / error строк. |
| `just headless-report` | `./scripts/emacs-headless-report.sh` | Печатает дату + hostname + версию Emacs + хвост последнего `run.log`. |
| `just logs-latest` | `./scripts/emacs-headless-report.sh` | Алиас для `headless-report`. |
| `just emacs-verify` | `./scripts/emacs-verify.sh both` | Алиас для `headless`. |
| `just network-contract` | `./tests/contract/pro-network-01.sh` | 5 чеков на сетевой слой. |
| `just emacs-sync` | `./scripts/dev-emacs-sync.sh` | Синхронизировать портативный Emacs-профиль в `~/.config/emacs`. |

## Кластер 5: Docker

Docker-рецепты — алиасы вокруг `lazydocker` и Docker CLI.
Предполагается, что пользователь в группе `docker` (задано в
`pro-users.nix`).

| Рецепт | Команда | Когда |
|--------|---------|------|
| `just d` | `lazydocker` | TUI: ps / logs / exec / restart / prune. |
| `just dl <name>` | `docker logs -f --tail 100 <name>` | Хвост логов. |
| `just dsh <name> [cmd]` | `docker exec -it <name> <cmd>` (default `sh`) | Shell в контейнер. |
| `just dr <name>` | `docker restart <name> && sleep 1 && docker logs --tail 30 <name>` | Restart + первые 30 строк. |
| `just dprune` | `docker system prune -f` + image + network | Cleanup. **Деструктивно.** |
| `just dscan <image> [severity]` | `trivy image --severity <severity> --no-progress <image>` | Скан уязвимостей. |
| `just dlint [<dockerfile>]` | `hadolint <dockerfile>` (default `Dockerfile`) | Линт Dockerfile. |
| `just dup` | `docker compose up -d` | Compose up. |
| `just ddown` | `docker compose down` | Compose down. |
| `just dps` | `docker compose ps` | Compose ps. |
| `just dclogs` | `docker compose logs -f --tail 50` | Compose logs. |

## Кластер 6: сайт (этот сайт)

| Рецепт | Команда | Когда |
|--------|---------|------|
| `just site-serve` | (ручной `zola serve` в `site/`) | Локальный preview с live reload. |
| `just site-build` | `nix build ".#site"` | Произвести финальный static-выход. |
| `just site-regen` | `scripts/site-regen.sh` | Регенерировать все auto-gen страницы. |

## Bootstrap-рецепты

| Рецепт | Команда | Когда |
|--------|---------|------|
| `just install` / `just install-nixos` | `./bootstrap/install.sh` | Bootstrap-скрипт. |
| `just install-emacs` / `just install-plain` | `./scripts/dev-emacs-sync.sh` | Синхронизировать Emacs в `~/.config/emacs`. |

## Алиасы

`switch` и `switch.sh` — алиасы (just-рецепт вызывает скрипт).
`check-fast` и `check-docs` — плейсхолдеры для будущей docs-only
быстрой проверки (сейчас no-op).

## Как разрешаются рецепты

`just` ищет рецепты в `justfile:1-164`. Shell установлен в
`bash -eu -o pipefail -c` для безопасности. Рецепты могут
использовать любую из:

* `nix` (subprocess)
* `sudo` (где требуется)
* `bash` (для логики внутри рецепта)
* Любую из just-переменных: `{{HOST}}`, `{{FLAGS}}`, `{{NAME}}`, `{{CMD}}`, `{{IMAGE}}`, `{{SEVERITY}}`, `{{DOCKERFILE}}`.

## Добавление нового рецепта

1. Решите, в какой кластер (build / submodules / agents / tests /
   docker / site / bootstrap).
2. Добавьте рецепт в `justfile` в соответствующей секции.
3. Документируйте его здесь в таблице выше.
4. Добавьте однострочный тест в `tests/contract/unit/`, если у
   рецепта есть нетривиальный side-effect.

## См. также

* [Быстрый старт](workflow/quickstart.md) — end-to-end онбординг.
* [Сабмодули](workflow/submodules.md) — политика SSH/HTTPS.
* [Troubleshooting](workflow/troubleshoot.md) — когда рецепт
  сбоит.
