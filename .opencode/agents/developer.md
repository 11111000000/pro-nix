---
description: Developer agent instructions — flake, Nix, Emacs tests and dev cycle
mode: subagent
---

Цель
----
Кратко: дать однозначный набор команд и порядок действий для разработки в этом репозитории, включая flake/Nix, контрактные и сценарные тесты, Emacs E2E и HDS-цикл (Change Gate). Агент, использующий этот файл, может автоматически предлагать и исполнять эти шаги при согласии пользователя.

Основные команды (локально)
---------------------------
- Проверка flake (CI-like):
  - `nix flake check` — запустить все определения checks и проверки flake.
  - При отладке: `nix flake check --show-trace`.
- Построить toplevel для хоста:
  - `nix build .#nixosConfigurations.<host>.config.system.build.toplevel`
- Собрать все хосты (flake app):
  - `nix run .#check-all` или `nix build .#checks.x86_64-linux.default` (в зависимости от flake outputs).
- Devshell (разработка с Emacs):
  - `nix develop .#devShells.x86_64-linux.default` — откроет shell с emacs и утилитами.
  - После входа devshell доступна обёртка `./.pro-emacs-wrapper/emacs-pro` (или `emacs-pro` в PATH).

Тесты и Verify (репозиторные проверки)
-------------------------------------
- HDS/Surface verification:
  - `./tools/holo-verify.sh` — проверяет HOLO.md, SURFACE.md и Proof файлы.
  - `./tools/surface-lint.sh` — линтер SURFACE.md (если есть).
  - `./tools/docs-link-check.sh` — проверка ссылок в документации.
- Контрактные тесты (Proofs):
  - `bash tests/contract/*.sh` — запускает скрипты `tests/contract/*` (например, `test_surface_health.spec`).
- Сценарии (vertical scenarios):
  - `bash tests/scenario/*.test` — запускает сценарные тесты (headless Emacs smoke и т.п.).
- Emacs headless E2E:
  - `./scripts/emacs-pro-wrapper.sh --batch -l scripts/emacs-e2e-assertions.el -l scripts/emacs-e2e-run-tests.el`
  - Альтернатива: `emacs --batch -l emacs/base/init.el -f ert-run-tests-batch` для ERT.

Примеры команд для быстрой проверки (подсказки)
----------------------------------------------
- Полный локальный verify (рекомендуется перед PR):
  - `nix flake check && ./tools/holo-verify.sh && bash tests/contract/test_surface_health.spec`
- Быстрый smoke dev цикл (без полной сборки хоста):
  - `nix develop .#devShells.x86_64-linux.default`
  - `./.pro-emacs-wrapper/emacs-pro --batch -l scripts/emacs-e2e-assertions.el -f some-smoke` (варианты)

Разработка — рекомендуемый цикл (HDS-aware)
-------------------------------------------
1. Создайте ветку `feat/<short-desc>`.
2. Обновите/добавьте Surface (если вы меняете публичные контракты) — редактировать `SURFACE.md` и пометить стабильность.
3. Добавьте/обновите Proof (tests) рядом с изменением: `tests/contract/*` или `tests/scenario/*`.
4. Локально прогоните Verify набор: `nix flake check` → `./tools/holo-verify.sh` → релевантные contract/scenario тесты → Emacs E2E.
5. Исправьте ошибки, повторите проверки.
6. В PR опишите Change Gate в описании PR (Intent, Pressure, Surface impact, Proof). Если вы трогаете [FROZEN], добавьте Migration блок.
7. По требованию CI-прохода или ревью — выполните `nix build` соответствующего toplevel и/или запустите Emacs E2E в CI-окружении.

AGENT-поведение (настройка для OpenCode / автоматизации)
-----------------------------------------------------
- Перед применением изменений агент должен требовать Change Gate (Intent/Pressure/Surface/Proof) при изменениях SURFACE.md или файлов с [FROZEN].
- Агент выполняет локальный Verify-пайплайн и возвращает отчёт с указанием команд для воспроизведения ошибок:
  - `nix flake check`
  - `./tools/holo-verify.sh`
  - `bash tests/contract/*.sh` и `bash tests/scenario/*.test`
  - Emacs headless E2E (опционально по флагу)
- Если Verify прошёл — агент формирует минимальный патч/коммит и предлагает PR описание, включающее Change Gate и инструкции по валидации.

CI и GitHub Actions
--------------------
- В репозитории есть workflow-ы: `.github/workflows/validate-pr.yml` и `emacs-e2e.yml`, которые:
  - используют flake devshell/inputs для запуска E2E Emacs и flake checks
  - запускают `./scripts/emacs-pro-wrapper.sh --batch ...` с заранее подобранным набором пакетов

Дополнительно
-------------
- Если хотите, агент может автоматически добавить/скопировать HDS tools из /home/az/Code/HDS в `tools/` для автономного Verify. Это следует делать явно (и коммитить).

Файлы, добавленные этим PR
--------------------------
- .github/PULL_REQUEST_TEMPLATE.md — шаблон PR с Change Gate
- docs/TESTING.md — инструкция по тестированию и валидации
- tools/surface-lint.sh — простой линтер для SURFACE.md
- tools/docs-link-check.sh — проверка локальных причастных ссылок в docs/

Рекомендации по PR и коммитам
------------------------------
- Один PR — одна основная цель (Single-Intent). Если нужно сделать несколько независимых вещей — разбейте на PR.
- Включите в коммит только файлы, относящиеся к Intent; не добавляйте побочные исправления без отдельного Intent.
- Всегда запускайте Verify перед PR (шаги выше) и приложите вывод ошибок/логов, если CI падает.

Автор: OpenCode helper (поместить в .opencode/agents для использования внутреннями агентами)
