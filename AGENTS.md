# Политика агентов pro-nix

## Роль репозитория
- pro-nix — воспроизводимая NixOS- и Emacs-конфигурация с публичными контрактами, фиксируемыми в `SURFACE.md`, и решениями, фиксируемыми в `HOLO.md`.
- Главная цель изменений: сохранять воспроизводимость, композиционность модулей и проверяемость поведения.
- Агенты должны понимать проект как систему политик и контрактов, а не как набор разрозненных файлов.

## Канонический порядок работы
0. Перед запуском `team-run` агент обязан привести рабочее дерево в чистое состояние:
   - закоммитить все локальные изменения в текущую ветку или создать временную ветку и закоммитить туда;
   - если автоматический коммит запрещён политикой оператора, агент должен приостановиться и запросить подтверждение у оператора;
   - коммиты должны иметь информативное сообщение, например: `chore: auto-commit before team-run` и включать краткое описание Intent run'а.
   - агент должен записать в артефакты run-а хеш коммита и список изменённых файлов.

1. Прочитать `AGENTS.md`, `SURFACE.md`, `HOLO.md`, `README.md`.
2. Определить Intent — одна доминирующая цель.
3. Определить зону ответственности: файл должен меняться там, где живёт политика, а не там, где проще сделать обход.
4. Оценить влияние на публичное поведение (SURFACE). Если влияет — обновить `SURFACE.md` и указать Proof.
5. Внести минимальные изменения в код/конфигурацию.
6. Запустить минимальный достаточный Verify для затронутой зоны. Полный host build не является проверкой по умолчанию.

## Карта ответственности
- `SURFACE.md` — публичные контракты и Proof. Менять только при изменении наблюдаемого поведения.
- `HOLO.md` — инварианты и решения. Менять только для правил, которые должны пережить одну задачу.
- `README.md` — карта репозитория для человека. Не дублировать подробный процесс агентов.
- `AGENTS.md` — рабочий протокол агентов: куда вносить правки и как их проверять.
- `flake.nix` — публичные flake outputs, overlays, apps, checks и передача specialArgs.
- `configuration.nix` — кросс-хостовая политика NixOS и импорт общих модулей.
- `modules/*`, `nixos/modules/*` — переиспользуемые NixOS-модули. Они добавляют вклад, но не финализируют хост.
- `hosts/*` — host-specific финализация и осознанные переопределения.
- `system-packages.nix` — workstation/runtime package set; не использовать для узкой user-only интеграции.
- `modules/packages-runtime.nix` — минимальный bootstrap runtime, не рабочая станция.
- `modules/pro-users*.nix` — пользователи, Home Manager wiring и user-level пакеты для всех пользователей.
- `emacs/home-manager.nix`, `emacs/core.nix` — декларативная доставка Emacs-профиля.
- `emacs/base/modules/*.el` — поведение Emacs. Одна функция — одна задача, поведение покрывается ERT.
- `nix/node-packages/*`, `nix/emacs-recipes/*`, `nix/overlays/*` — упаковка и overlays; package-only правки проверяются сборкой пакета.
- `scripts/*` — runtime/ops entrypoints. Проверять `--help` или короткий smoke.
- `tools/*` — проверочные инструменты. Быстрый режим должен быть дефолтным, полный — явным.
- `tests/contract/*` — Proof для контрактов. Один тест подтверждает один контракт.

## Минимальный Verify
Правило: сначала проверяется самый маленький затронутый артефакт. Если проверка начинает строить несвязанные closures или host-профили, остановитесь и сузьте команду.

- Документация без изменения поведения: `./tools/surface-lint.sh`.
- `SURFACE.md` или Proof-реестр: `./tools/surface-lint.sh` и только затронутый Proof.
- `HOLO.md` или процессные правила: `./tools/surface-lint.sh`.
- Emacs Lisp синтаксис: `./tools/holo-verify.sh elisp`.
- Emacs Lisp поведение: целевой ERT-файл или `PRO_PACKAGES_AUTO_INSTALL=0 ./scripts/test-emacs-headless.sh tty`.
- Nix package derivation: `nix build` только этого derivation.
- Overlay: `nix eval` наличия атрибута и `nix build` затронутого пакета.
- Home Manager user package: `nix eval --json .#nixosConfigurations.<host>.config.home-manager.users.<user>.home.packages`.
- `system-packages.nix`: `tests/contract/unit/09-system-packages-eval.sh` и eval `environment.systemPackages`.
- NixOS module option/config: `nix eval --json .#nixosConfigurations.<host>.config.<точный.attr>`.
- systemd unit generation: `./scripts/verify-units.sh` или targeted `systemd-analyze verify`.
- Host config: сначала `nix eval` точного host-атрибута; host build только если изменена host-level финализация.
- `flake.nix` outputs/checks/apps: `nix flake show` или targeted `nix eval`; `nix flake check` только если менялись публичные outputs/checks.
- `scripts/*`: `<script> --help` или минимальный smoke.
- `tools/*`: запустить изменённый tool в самом дешёвом режиме.
- Контрактный тест: запустить только изменённый `tests/contract/...` test.

Эскалация к `nix build .#nixosConfigurations.<host>.config.system.build.toplevel`, `nix flake check` или `nix run .#check-all` допустима только когда локальный Proof не покрывает риск, меняется публичный flake output, меняется host finalization, или пользователь явно просит полную проверку.

## Change Gate
Любое изменение оформляется через Change Gate.

- Intent: одна строка о цели изменения.
- Pressure: `Bug`, `Feature`, `Debt` или `Ops`.
- Surface impact: какие элементы `SURFACE.md` затронуты и какова их стабильность.
- Proof: какие команды, тесты или CI-job подтверждают изменение.
- Migration: обязательна, если затронут `FROZEN`-контракт.

Правило отказа:
- Если изменение касается `SURFACE.md` с пометкой `[FROZEN]`, а Change Gate или Proof отсутствуют, агент должен остановиться и запросить недостающие данные.

## Правила письма
- Все комментарии, пояснения, docstring и документация в этом репозитории пишутся на русском языке.
- Стиль: точный, сжатый, учебный, как в хорошем учебнике по computer science.
- Пишите не «пожелания», а контракты: цель, инварианты, ограничения, эффекты, проверки.
- Избегайте общих слов вроде «удобно», «красиво», «лучше» без операционного смысла.
- Если термин может быть понят неправильно, определяйте его явно.

## Правила для Nix
- Модуль должен вносить вклад, а не финализировать мир.
- Предпочтение: `lib.mkDefault`, композиция списков, локальные опции.
- `lib.mkForce` допустим только на уровне host-конфигурации, когда нужна окончательная фиксация политики.
- Не строить модульные списки через прямую зависимость от `config.environment.systemPackages`, если это создаёт рекурсию или скрытую связанность.
- Разбивать крупные Nix-файлы на модули по ответственности.
- При формировании `systemd.services.<name>.serviceConfig.ExecStart` используйте простые и надёжные подходы:
  * Не используйте `pkgs.writeShellScriptBin` внутри строки `ExecStart = ...` — это приводит к некорректному превращению derivation в путь, что оставляет `"` в конце.
  * Используйте явное указание пути: `ExecStart = "${pkgs.writeShellScriptBin "name" ''...''}/bin/name";` (отдельно от строки) или `ExecStart = ''/bin/sh -c ''...'';`.
  * Всегда проверяйте сгенерированный unit-файл через `systemd-analyze verify` перед активацией.

## Правила для Emacs Lisp
- Одна функция — одна задача.
- Публичные функции обязаны иметь docstring с кратким контрактом.
- Побочные эффекты должны быть локализованы и описаны.
- Изменения поведения должны сопровождаться ERT-тестами.
- Избегайте длинных монолитных функций; выносите шаги в отдельные helper-функции.

## Правила для структуры кода
- Один файл — одна ответственность.
- Не смешивайте экспериментальный код с каноническими модулями.
- Если файл начинает описывать две сущности, разделите его.
- При споре о границах модуля выбирайте более узкую и проверяемую границу.

## Критерии качества агента
- Агент не должен «улучшать всё сразу».
- Агент должен выбирать минимальный дифф, который закрывает Intent.
- Агент должен предпочитать существующий паттерн проекта новому абстрактному решению.
- Агент должен уметь объяснить, почему правка безопасна и как она проверяется.

## Управление проектом
- Большие изменения делятся на этапы: Surface, Proof, Code, Verify.
- Если изменение затрагивает несколько подсистем, сначала сократите Intent.
- Если правка требует миграции, опишите rollback заранее.
- Если изменения можно выразить меньшим количеством файлов, так и делайте.

## Проверки
- Проверки выбираются по разделу «Минимальный Verify».
- `nix fmt`, `nix flake check` и full host build не являются обязательным дефолтом.
- Перед коммитом достаточно запустить Proof из Change Gate и быстрый lint для изменённых контрактных документов.
- Полная матрица запускается перед release, при изменении flake outputs или по явной просьбе пользователя.

### Как тестировать этот репозиторий
- Базовый lint для документов контракта и процессов:
  - `./tools/surface-lint.sh`
- Проверка Emacs Lisp:
  - синтаксис: `./tools/holo-verify.sh elisp`
  - поведение: целевой ERT-файл или `PRO_PACKAGES_AUTO_INSTALL=0 ./scripts/test-emacs-headless.sh tty`
- Проверка systemd unit-ов:
  - `./scripts/verify-units.sh`
  - либо targeted `systemd-analyze verify` для конкретного unit-файла
- Проверка скриптов:
  - `<script> --help` или минимальный smoke-run
- Проверка Nix package/overlay:
  - `nix build` только затронутого derivation
  - `nix eval` наличия нужного атрибута
- Проверка NixOS module/host config:
  - `nix eval --json .#nixosConfigurations.<host>.config.<точный.attr>`
  - host build только если изменена host-level финализация
- Проверка flake outputs/checks/apps:
  - `nix flake show` или targeted `nix eval`
  - `nix flake check` только при изменении публичных outputs/checks
- Проверка VM/контрактных регрессий:
  - запуск только изменённого `tests/vm/*` или `tests/contract/*`
  - для VM-тестов используйте `nix build .#checks.x86_64-linux.<имя>`
- Проверка live-активации перед `just switch` / `nixos-rebuild switch`:
  - сначала `nix --extra-experimental-features 'nix-command flakes' eval --json .#nixosConfigurations.<host>.config.environment.systemPackages`
  - для изменений в `system-packages.nix` дополнительно `tests/contract/unit/09-system-packages-eval.sh`
  - если preflight/eval падает, live-активация запрещена

### Обязательный preflight перед `just switch` / `nixos-rebuild switch`
- Перед live-активацией агент обязан проверить вычислимость профиля пакетов:
  - `nix --extra-experimental-features 'nix-command flakes' eval --json .#nixosConfigurations.<host>.config.environment.systemPackages`
- Для изменений в `system-packages.nix` агент обязан запускать:
  - `tests/contract/unit/09-system-packages-eval.sh`
- Если preflight/eval падает, live-активация запрещена. Сначала исправляется причина,
  затем повторяются preflight-проверки.

## Конфликты и сомнения
- При сомнении следуйте существующему стилю репозитория, а не абстрактному идеалу.
- Если требование конфликтует с воспроизводимостью или читаемостью, приоритет у воспроизводимости и проверяемости.
- Если задача расплывчата, сначала уточните Intent, а не пишите код.

## Политика: работа в primary worktree

Цель: упростить рабочий поток для операторов и агентов в ситуациях, где linked worktree
не подходит. Ранее репозиторий содержал helper-скрипт для создания linked worktree,
но по решению оператора скрипт удалён и строгая обязанность использовать linked worktree
ослаблена.

Правило: работа в primary worktree допустима; агенту рекомендуется работать в отдельной ветке ради ясности, но это не обязано. Для критичных изменений по-прежнему требуется Change Gate и Proof.

Рекомендации для агентов:

- Работайте в отдельной ветке, когда это возможно, но прямые правки в primary worktree допустимы по соглашению с оператором.
- Для массовых или рискованных изменений всё ещё создавайте временную ветку и документируйте причину работы в primary worktree в PR/коммите.
- Для автоматизированных run'ов и CI соблюдайте минимальные Verify и Change Gate.
<!-- PI-CREW:GUIDANCE:START -->
<!-- PI-CREW:BLOCK:pi-crew-overview -->
## pi-crew

> Managed by **pi-crew v0.2.20** — do not edit this section manually.

pi-crew is a Pi extension for coordinated AI agent teams, workflows,
worktrees, and async task orchestration.
<!-- PI-CREW:/BLOCK:pi-crew-overview -->

<!-- PI-CREW:BLOCK:pi-crew-commands -->
### Quick Commands

| Command | Description |
|---|---|
| `team action='init'` | Initialize pi-crew for this project |
| `team action='run'` | Start a team run |
| `team action='status'` | Check run status |
| `team action='list'` | List available teams/agents/workflows |
| `team action='recommend'` | Get team/workflow recommendations |
<!-- PI-CREW:/BLOCK:pi-crew-commands -->
<!-- PI-CREW:GUIDANCE:END -->
