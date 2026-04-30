## Вклад в pro-nix

CONTRIBUTING.md — это руководство для контрибьюторов и операторов. Оно описывает
пошаговый процесс внесения изменений, требования к Proof и формат Change Gate.

Коротко: одна цель — одно изменение. Если задача затрагивает несколько
подсистем, сначала сузьте Intent до однофокусного PR.

Перед началом работы

1. AGENTS.md — политика агентов и инженерные ограничения.
2. SURFACE.md — публичные контракты и Proof-команды.
3. HOLO.md — инварианты и архитектурные решения.
4. README.md — обзор и карта репозитория.
5. CONTRIBUTING.md — этот документ.

Change Gate (обязателен для публичных изменений)

В PR-описании приведите Change Gate в формате ниже. Для простых правок этот
блок может быть коротким; для изменений, затрагивающих `[FROZEN]`, заполните
все поля и приложите Proof до изменения кода.

```text
Intent: <краткая цель изменения (1 строка)>
Pressure: <Bug | Feature | Debt | Ops>
Surface impact: (none) | touches: <SURFACE item(s)> [FROZEN/FLUID]
Proof: <команды, тесты или файлы, которые подтверждают изменение>

## Краткое описание
- Что: <одно предложение>
- Зачем: <краткое объяснение>
- Результат: <что меняется для оператора/пользователя>
- Риски: <ключевые риски и допущения>

## Checks
- [ ] Обновлён SURFACE.md, если менялось публичное поведение
- [ ] Proof для `[FROZEN]` поверхностей добавлен/обновлён
- [ ] Запущен `nix fmt`
- [ ] Запущен `nix flake check`
- [ ] Запущен `./tools/surface-lint.sh`
- [ ] Запущен `./tools/holo-verify.sh`

## Migration (только для `[FROZEN]`)
- Impact: <что меняется>
- Strategy: <additive_v2 | feature_toggle | break_with_window>
- Window/Version: <версия или окно миграции>
- Data/Backfill: <что нужно перенести или "n/a">
- Rollback: <план отката>
- Tests: Keep: <что сохраняется>, Add: <что добавляется>
```

Surface First

Порядок изменения публичного поведения: Surface → Proof → Code → Verify.

- Если изменение не меняет наблюдаемое поведение, укажите `Surface impact: none`.
- Для FLUID-поверхностей обновите SURFACE.md по необходимости.
- Для FROZEN-поверхностей подготовьте Migration и Proof заранее — код вносится
  только после того, как Proof проходит.

Правила письма и формат

- Документы, docstring и комментарии — на русском языке.
- Пишите контрактно: цель, инварианты, ограничения, эффекты, проверки.
- Избегайте субъективных формулировок без критериев проверки.

Nix-правила (кратко)

- Модуль должен расширять систему, а не финализировать её.
- Предпочитайте `lib.mkDefault` и композицию списков.
- `lib.mkForce` — допустим только на host-уровне.
- Не создавайте рекурсивные зависимости через `config.environment.systemPackages`.
- Для systemd `ExecStart` используйте явные пути и простые shell-команды —
  не вставляйте `pkgs.writeShellScriptBin` внутрь строки.

Дополнительные preflight-команды для пакетов

```bash
nix --extra-experimental-features 'nix-command flakes' eval --json .#nixosConfigurations.<host>.config.environment.systemPackages
bash tests/contract/unit/09-system-packages-eval.sh
```

Emacs-лисп правила

- Одна функция — одна задача.
- Публичная функция — docstring с контрактом.
- Побочные эффекты описаны и локализованы.
- Изменения поведения сопровождаются ERT-тестом или обоснованием отсутствия теста.

Проверки и CI

Минимальный набор локальных проверок:

```bash
./tools/surface-lint.sh
./tools/holo-verify.sh
nix flake check
```

Для полного набора:

```bash
nix run .#check-all
```

Pull Request checklist

1. Intent сформулирован одной строкой
2. Change Gate заполнен в PR-описании
3. Surface impact корректен
4. Для FROZEN есть Migration и Proof
5. Секреты и machine-local state не попали в коммит
6. Релевантные Proof-команды запущены

Безопасная практика разработки

- Делайте минимальный diff для закрытия Intent
- Один PR — одна доминирующая цель
- Избегайте смешивания экспериментального кода с каноническими модулями

Canary и rollback

Если изменение влияет на сеть, ключи, systemd unit или live-активацию — опишите
canary и план отката в PR-описании.

Секреты

В репозитории нельзя хранить приватные ключи, API-токены или незашифрованные
credentials. Если нужен секрет — укажите operator-managed механизм (sops/age,
host overlay и т.п.).

Эскалация

Если FROZEN-поверхность или критическая инфраструктура затронута, согласуйте
план с владельцем поверхности. Если владелец недоступен – откройте draft PR с
Change Gate и Migration; добавьте контактную информацию и минимальный Proof.

Финальная нота

Фокус проекта — безопасная эволюция воспроизводимой системы, а не скорость
изменений.

---

Работа с opencode — ветки и git worktree

Если у вас несколько копий / агентов, которые одновременно разрабатывают репозиторий,
рекомендуем использовать правило "one agent = one branch" в сочетании с `git worktree`.

Конвенция имён веток

- opencode/<agent-id>/<feature-slug>

Примеры:

- opencode/agent42/soft-reload-fix
- opencode/session-20260430T095920Z/iter1

Создание ветки и worktree (ручной способ)

1. Создать ветку (от ветки, от которой хотите ответвиться, например origin/main):

```bash
git fetch origin
git checkout -b opencode/<agent-id>/<feature> origin/main
```

2. Создать отдельный рабочий каталог с привязанной веткой:

```bash
git worktree add ../pro-nix-<agent-id>-<feature> opencode/<agent-id>/<feature>
cd ../pro-nix-<agent-id>-<feature>
```

3. Работать в этом каталоге: правки, коммиты, push.

```bash
git add ... && git commit -m "feat: ..." && git push -u origin opencode/<agent-id>/<feature>
```

Удаление worktree и ветки

```bash
cd /path/to/original/repo
git worktree remove ../pro-nix-<agent-id>-<feature>
git branch -D opencode/<agent-id>/<feature>
git push origin --delete opencode/<agent-id>/<feature>
```

Автоматизация: helper-скрипт

В репозитории есть `scripts/create-opencode-branch.sh` — он создаёт ветку,
пишет шаблон метаданных `.opencode/opencode-<agent>.json.template` и пушит ветку.
Использование:

```bash
./scripts/create-opencode-branch.sh <agent-id> <feature-slug>
# затем вручную создайте worktree, как выше, или используйте git worktree add
```

Примечания и ограничения

- `git worktree` полезен, когда несколько worktree размещены на одной машине
  (экономит место и разделяет рабочие каталоги). Каждый worktree имеет свои
  незакоммиченные изменения и свой checked-out branch.
- Один worktree не может иметь более одной checked-out ветки одновременно.
- Не коммитьте per-agent секреты в ветку; используйте `.opencode/*.json` как
  gitignored шаблон для локальной конфигурации.
