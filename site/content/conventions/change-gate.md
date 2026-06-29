+++
title = "Change-Gate"
template = "page.html"
weight = 3

[extra]
tldr = "Формат PR body: Intent / Pressure / Surface / Proof. [FROZEN] поверхности требуют migration notes. Валидируется actions/check-change-gate/action.sh."

[[extra.next]]
title = "Мёртвый код"
url = "/conventions/dead-code/"
+++

# Change-Gate

Каждое тело PR должно содержать четыре поля: `Intent`,
`Pressure`, `Surface impact`, `Proof`. Это формальная замена
unstructured описания изменений.

## Формат

```markdown
Intent: [одной строкой опишите цель изменения]
Pressure: [Bug | Feature | Debt | Ops]
Surface impact: (none) | touches: <SURFACE item(s)> [FROZEN/FLUID]
Proof: tests: <команды или файлы, подтверждающие изменение>
```

* **Intent** — что вы пытаетесь достичь, одним предложением. Не
  «что сделали» — «зачем».
* **Pressure** — категория изменения: `Bug` (багфикс), `Feature`
  (новая фича), `Debt` (рефакторинг, очистка), `Ops` (операционное —
  скрипт, CI, инфра).
* **Surface** — какая публичная поверхность затрагивается. `(none)`
  для внутренних правок. `touches: <item>` для всего, что видно
  снаружи. Пометьте `[FROZEN]` для стабильных контрактов (любое
  изменение требует migration notes) и `[FLUID]` для in-progress.
* **Proof** — что подтверждает, что изменение работает: имя
  контракта, лог CI, скриншот, ручной шаг.

## Пример хорошего PR body

```markdown
Intent: Fix dbus-broker restart loop on cf19 during nixos-rebuild switch.
Pressure: Bug
Surface impact: touches: systemd.services.dbus.reloadIfChanged [FROZEN]
Proof: tests: tests/vm/cf19-switch-dbus-regression.nix

## Краткое описание

- hosts/cf19/configuration.nix: добавлен `lib.mkForce false` для
  четырёх dbus-опций.
- Тест-фикстура добавлена в tests/vm/.

## Проверки

- [x] Я обновил `SURFACE.md`, если менялось публичное поведение.
- [x] Я добавил или обновил Proof для `[FROZEN]` поверхностей.
- [x] Я запустил `./tools/holo-verify.sh`.
```

## FROZEN vs FLUID

* **[FROZEN]** — стабильный контракт. Любое изменение требует
  migration notes. Пользователи могут зависеть от этого (явно или
  неявно). Пример: `services.tor.enable` (все хосты его
  используют), `pro.hosts.desktop.tailnet` (mesh-имя desktop'а).
* **[FLUID]** — in-progress. Изменения ожидаемы. Migration notes
  не нужны. Пример: внутренний `pro-buffer-banner` geometry (никто
  не зависит).

## Migration

Заполняется только для `[FROZEN]`-поверхностей. Шаблон:

```markdown
Migration: (none для FLUID, обязателен для FROZEN)

- Impact: <что меняется>
- Strategy: additive_v2 | feature_toggle | break_with_window
- Window/Version: <окно или версия>
- Data/Backfill: <что нужно перенести или "n/a">
- Rollback: <безопасный откат>
- Tests:
  - Keep: <что сохраняется>
  - Add: <что добавляется>
```

`additive_v2` — добавить новую опцию, не ломая старую. `feature_toggle`
— завести фич-флаг, выключенный по умолчанию. `break_with_window` —
прямой break, но с заранее объявленным окном для миграции.

## Как валидируется

`.github/actions/check-change-gate/action.sh` валидирует наличие
четырёх полей. Изначально workflow возвращает exit 78 (BSD
`EX_CONFIG`, не блокирующий) для отсутствующих полей, чтобы
проект развернул gate без поломки существующих PR. Цель — потом
переключить на блокирующую проверку.

`change-gate.yml` workflow — это и есть эта проверка.

## Check-list перед PR

В шаблоне PR (`PULL_REQUEST_TEMPLATE.md`) уже есть:

```markdown
## Проверки

- [ ] Я обновил `SURFACE.md`, если менялось публичное поведение.
- [ ] Я добавил или обновил Proof для `[FROZEN]` поверхностей.
- [ ] Я запустил `./tools/holo-verify.sh`.
```

`SURFACE.md` и `HOLO.md` — живые документы, перечисляющие
публичные поверхности (NixOS-опции, defcustom'ы, клавиши,
скрипты) и инварианты, которые система обещает соблюдать. Если
ваш PR меняет что-то в этом списке — обновите документ в том же
коммите.

## Docs-only PR

Для правки только документации (без изменения кода) есть
отдельный шаблон — `PULL_REQUEST_TEMPLATE_DOCS.md`. В нём
отсутствует `Migration`-секция, и `Pressure: Debt` —
естественный выбор.

## Частые ошибки

* ❌ `Intent: Updated pro-foo.el` — это **что** сделали, не **зачем**.
  Правильно: `Intent: Add custom defcustom for buffer-banner
  position so users can choose :top or :bottom`.
* ❌ `Surface impact: all` — слишком грубо. Перечислите конкретные
  опции / клавиши / модули.
* ❌ `Proof: works on my machine` — не proof. `Proof: tests: nix
  flake check; manual: getent hosts desktop.local` — proof.

## Где смотреть

* `PULL_REQUEST_TEMPLATE.md` — основной шаблон.
* `PULL_REQUEST_TEMPLATE_DOCS.md` — для docs-only.
* `.github/actions/check-change-gate/action.sh` — валидатор.
* `AGENTS.md` §5 — общий контекст по governance.
