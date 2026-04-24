# System Reminder — UX/UI Priorities & Plan (selected)

Этот документ даёт детализованный диалектический анализ и пошаговый план работы для выбранных приоритетов UI/UX Emacs в pro-nix.
Выбранные пункты (из общего анализа):
- 1) Accessibility и контрастность
- 2) GUI smoke testing & headful validation
- 4) IME / платформа (input parity)
- 5) Keybinding discoverability & conflict resolution
- 7) Startup performance metrics & lazy-loading policy
- 8) Session management и workspace restore
- 9) TTY/SSH parity & fallbacks

Документ структурирован по каждому пункту: тезис → антитезис → синтез, затем конкретные таски, Proof (тесты/команды), предполагаемые файлы/скелеты, оценка усилий, риски и смягчения.

Общие HDS-принципы
- Все изменения, затрагивающие public surface или [FROZEN] элементы, должны следовать Change Gate: Intent, Pressure, Surface impact, Proof.
- Для каждого нового публичного поведения добавить запись в SURFACE.md и ссылку на Proof (ERT/скрипты/CI job).

1) Accessibility и контрастность

Тезис
- В репозитории есть темы и UI-модули, но нет единой политики доступности (контраст, масштабирование, размер шрифта). Это приводит к разнообразию тем с возможным плохим читабельным контрастом.

Антитезис
- Жёсткие требования к контрасту ломают творчество пользователей и кастомные темы. Некоторые пользователи предпочитают низкий контраст.

Синтез
- Ввести политику: набор рекомендуемых профилей (default, high-contrast, large-text). Не навязывать, но тестировать и гарантировать, что дефолтный профиль удовлетворяет базовым критериям читабельности.

Минимальные таски
1. Добавить запись в SURFACE.md: "Accessibility / Theme baseline" (FLUID) с Proof командой.
2. Реализовать ERT-тест `tests/contract/test-theme-contrast.el`:
   - Проверяет, что face `default` имеет соотношение яркостей fg/bg >= порога (примерно WCAG AA ~4.5:1 для маленького текста). Простая аппроксимация через вычисление яркости RGB.
3. Добавить конфигурационный ключ (design-only сначала): `pro.emacs.ui.accessibility = {profile = "default" | "high-contrast" | "large"}`.

Proof / команды
- `emacs --batch -l emacs/base/init.el -f ert-run-tests-batch` (запуск ERT включая test-theme-contrast)

Предполагаемые файлы / skeletons
- tests/contract/test-theme-contrast.el (новый)
- docs/accessibility.md (описание профилей)

Оценка усилий
- 1–2 developer-days (spec + тест + docs)

Риски и смягчения
- Ложные срабатывания для пользовательских тем — пометить тест как non-blocking для кастомных тем и только blocking для pro-nix default theme.

2) GUI smoke testing & headful validation

Тезис
- Headless ERT присутствует, но GUI специфические фичи (child-frame, posframe, icon fonts) не покрыты CI, поэтому regressions могут появляться незаметно.

Антитезис
- Headful тесты сложнее: требуют Xvfb/runner и нестабильны с пиксельными проверками. Это увеличит CI время/сложность.

Синтез
- Добавить независимую GUI-smoke job, выполняемую в Xvfb; вместо pixel-tests проверять признаки (наличие child-frame, posframe API, font availability, корректное создание фрейма/окна). Пиксельные проверки — опциональны и должны быть терпимыми к небольшим отклонениям.

Минимальные таски
1. Добавить скрипт `tests/gui/gui-smoke.el` (emacs-lisp) который:
   - Запускается с Xvfb (в CI) и `emacs --batch` или `emacs --quick`.
   - Загружает минимальный UI-модуль и проверяет: `display-graphic-p`, создание child-frame, `corfu-posframe` availability, `font-family-list` содержит ожидаемые шрифты.
2. Добавить GitHub Actions job `gui-smoke` с запуском Xvfb и вызовом скрипта.

Proof / команды
- `./.pro-emacs-wrapper/emacs-pro -Q -l tests/gui/gui-smoke.el` (local)

Предполагаемые файлы
- tests/gui/gui-smoke.el
- .github/workflows/gui-smoke.yml (опционально gated)

Оценка усилий
- 2–4 developer-days (скрипт + CI job + отладка на runner)

Риски и смягчения
- CI runner может не поддерживать GUI; использовать Xvfb в контейнере, флаг gate чтобы job запускался только при изменениях в emacs/ UI модулях.

3) IME / платформа (input parity)

Тезис
- Много пользователей используют нелатинские вводы (CJK, IME). В репозитории есть упоминания w32-ime; однако нет стандартизованного тестирования IME поведения и документированных адаптеров для Wayland/macOS/Windows.

Антитезис
- Эмулировать IME в CI сложно; изменения могут оставаться недетектированными. Часть платформа-специфичных багов надо ловить вручную.

Синтез
- Создать платформенную матрицу, документировать known caveats и создать ручные тест-кейсы. Для автоматизации — проверять API availability и поведение composition callbacks там, где возможно (например w32-ime on Windows runner).

Минимальные таски
1. Инвентаризация: файл `docs/platform-input.md` с таблицей (Linux X11, Wayland, macOS, Windows) и текущими status/caveats.
2. Добавить SURFACE.md заметку про IME behavior (FLUID).
3. Добавить manual test checklist и инструкции для воспроизведения IME issues (скрипты, команды).

Proof / команды
- Manual guided tests; автоматические smoke checks где доступны (w32-ime presence on Windows runners).

Предполагаемые файлы
- docs/platform-input.md
- tests/manual/README-ime.md (инструкция для тестера)

Оценка усилий
- 1–3 developer-days (документация + checklist). Исправления платформенные — отдельные задачи.

Риски и смягчения
- Невозможность полноавтоматического тестирования — документировать и привлекать контрибьюторов с платформами.

4) Keybinding discoverability & conflict resolution

Тезис
- Есть `emacs-keys.org` и suggestion merge flow, но нет интерактивного UX для приёма/отклонения предложений и управления конфликтами.

Антитезис
- Автоматические диалоги могут раздражать опытных пользователей; интерактивные шаги требуют UI, который нужно поддерживать.

Синтез
- Добавить opt-in onboarding step и команду для разрешения конфликтов: `pro-emacs-keys-resolve`. Логировать результаты и сохранять принятые решения в ~/.config файле.

Минимальные таски
1. Документировать current merge algorithm (emacs/base/modules/keys.el) в docs/keys-workflow.md.
2. Реализовать команду `pro-emacs-keys-resolve` (stub) и интерактивный prompt, который показывает конфликтующие биндинги и позволяет выбрать. Скелет: `emacs/base/modules/keys-resolver.el`.
3. Добавить ERT-тест `tests/contract/test-keys-merge.el` для немануальной логики слияния.

Proof / команды
- `emacs --batch -l emacs/base/init.el --eval '(pro-emacs-keys-resolve-run-tests)'` (ERT)

Предполагаемые файлы
- emacs/base/modules/keys-resolver.el (новый)
- tests/contract/test-keys-merge.el
- docs/keys-workflow.md

Оценка усилий
- 1–3 developer-days

Риски и смягчения
- Интерактивный UX может быть навязчив — сделать opt-in и доступной командой для повторного запуска.

5) Startup performance metrics & lazy-loading policy

Тезис
- Нет систематического сбора метрик запуска; lazy-loading решает UX, но без измерений действия слепы.

Антитезис
- Лёгкая телеметрия может быть шумной и объемной; не хотим отправлять данные наружу. Нужно держать данные локальными.

Синтез
- Собрать локальные метрики startup (time-to-first-input, time-to-ready, module load times) и хранить в `~/.local/state/pro-emacs/metrics.json`. Использовать эти данные для принятия решений о lazy-load.

Минимальные таски
1. Добавить `emacs/base/modules/startup-metrics.el` — логирует тайминги при загрузке основных модулей.
2. Добавить `scripts/emacs-print-metrics.sh` для обработки и печати результатов.
3. Добавить CI command для запуска quick-start benchmark.

Proof / команды
- `emacs --batch -l emacs/base/init.el --eval '(pro-emacs-startup-metrics-write)'` и просмотр `~/.local/state/pro-emacs/metrics.json`.

Предполагаемые файлы
- emacs/base/modules/startup-metrics.el
- scripts/emacs-print-metrics.sh

Оценка усилий
- 0.5–1.5 developer-days

Риски и смягчения
- Шум в логах — агрегировать и очищать старые записи; не отправлять данные внешним сервисам без явного согласия.

6) Session management и robust workspace restore

Тезис
- Существуют механизмы session restore, но они не детализированы и не протестированы на сложных состояниях (vterm, LSP, sockets).

Антитезис
- Полное восстановление внешних процессов невозможно; гарантий restore should be explicit about scope.

Синтез
- Определить контракт: что гарантированно восстанавливается (буферы, позиции, open files, window-config), что нет (external processes). Реализовать безопасное snapshot/restore для поддерживаемых элементов.

Минимальные таски
1. Документировать contract: `docs/session-contract.md`.
2. Реализовать простой snapshot writer `emacs/base/modules/session-serializer.el` (save buffer list, file positions, window-config by `window-state-get`).
3. Реализовать restore helper, который пытается восстановить и логирует несопоставимые объекты.
4. Добавить ERT: `tests/contract/test-session-restore.el` — симулирует snapshot, restart и restore for basic items.

Proof / команды
- `./scripts/emacs-pro-wrapper.sh --batch -l tests/contract/test-session-restore.el -f ert-run-tests-batch`

Оценка усилий
- 2–5 developer-days

Риски и смягчения
- Не все типы буферов восстанавливаются (vterm) — document and provide manual guidance.

7) TTY/SSH parity & fallbacks

Тезис
- Многие пользователи работают по SSH / TTY; GUI features должны иметь понятные fallback-режимы.

Антитезис
- Полная паритета невозможна; некоторые UX элементы (icons, child-frames) недоступны в TTY.

Синтез
- Формализовать fallback policy: все GUI features должны иметь терминальные альтернативы или gracefully degrade. Отдельно тестировать `emacs -nw` загрузку и минимальный UX.

Минимальные таски
1. Audit `emacs/base/modules/ui-tty.el` и гарантировать набор fallback настроек.
2. Добавить ERT `tests/contract/test-tty.el` — запускает `emacs -nw` в pty (headless) и проверяет, что основные функции (modeline, completion fallback) работают.

Proof / команды
- `emacs -Q -nw -l tests/contract/test-tty.el --batch` (или wrapper)

Оценка усилий
- 0.5–1.5 developer-days

Риски и смягчения
- Различия терминалов — покрыть 256-color / truecolor и основные $TERM вариации в документации.

Roadmap и последовательность работ (минимально-инвазивный путь)
1. Документация и Surface: добавить/обновить записи в SURFACE.md и docs/* для Accessibility, IME, Keys, Session, TTY. (0.5–1d)
2. Быстрые тесты и инструменты (быстрые победы):
   - test-theme-contrast.el
   - startup-metrics.el
   - pro-emacs-check-fonts (runtime check)
   - basic session snapshot writer (lightweight)
   (примерно 2–4d)
3. GUI smoke CI job (Xvfb) — конфигурация и отладка (2–4d)
4. Keybinding resolver и onboarding wiring (1–3d)
5. Session restore hardening и soft-reload integration (следующая итерация, 1–2 sprints)
6. Platform IME work — параллельно, с привлечением тестеров по платформам.

Ownership и кому назначать
- Owner (Lead): emacs/core maintainer — координация Soft Reload, session restore.
- Owner (Docs & Tests): инженер QA / Docs — написать docs и ERT skeletons.
- Owner (CI): DevOps — добавить Xvfb job и CI policy.

Change Gate / Proof requirements
- Для всех изменений в поведении UI добавить запись в SURFACE.md и Proof (ERT path or CI job). Для Soft Reload (FROZEN) proof обязателен перед включением по умолчанию.

Следующие конкретные точки действий (готовые PR-и):
1. PR: docs + SURFACE updates (accessibility, IME note, keys, session contract) — small, non-invasive (I can open).
2. PR: ERT `test-theme-contrast.el` + startup-metrics skeleton + pro-emacs-check-fonts reporter.
3. PR: GUI smoke test skeleton + GitHub Action (gated to run on UI changes).
4. PR: keys-resolver.el skeleton and ERT for merge logic.
5. PR: session-serializer minimal implementation + ERT.

Если подтвердите, начну с PR №1 (docs + SURFACE updates) и PR №2 (ERT skeletons). После их слияния продолжим с GUI smoke CI.

---
Прошу подтвердить: начать с PR №1 (docs & SURFACE) и PR №2 (ERT skeletons: theme-contrast, startup-metrics, fonts-check). После подтверждения начну вносить и закоммитю изменения.
