# План миграции полезных частей из ~/pro в pro-nix (диалектический анализ)

Цель
- Синхронизировать только «важное и удобное» из ~/pro в pro-nix: сохранить привычный UX для навигации и автодополнения, не раздувая репозиторий ненужными экспериментами.

Короткий вывод (итог):
- Уже перенесено/реализовано: vertico/consult/orderless, consult helpers (pro/consult-find, pro/consult-buffer), vertico keybindings, corfu/cape базовая интеграция, загрузка биндов из org.
- Что ещё стоит перенести: EXWM/симуляция клавиш, pro-tabs (если используется), расширенные ключи и небольшие helper-файлы из ~/pro, дополнительные consult-расширения и UI‑плюшки, инструменты workflow (avy, expand-region, yasnippet, projectile, treemacs), скрипты автогенерации keys.el, small automation utilities.

Диалектический разбор
- Тезис: pro-nix должен быть минимален, воспроизводим и прост для других машин (минимальный набор пакетов).
- Антитезис: ~/pro — рабочая, отлаженная конфигурация с множеством мелких удобств; отказ от них ухудшит UX и будет постоянно возвращать запросы "а где моя кнопка?".
- Синтез: переносим те составляющие, которые дают большую пользу при небольшом риске и поддерживаемости. Оставляем экспериментальные/пользовательские вещи в ~/pro и делаем их опциональными (lazy require, defcustomы).

Приоритеты (как решать)
1. Критически полезное (высокий приоритет) — переносим сразу
  - EXWM input-simulation keys и exwm-input-set-keys макрос: обеспечивает ожидаемую симуляцию клавиш и совместимость hotkeys.
  - pro-tabs: улучшения для табов (если команда активно использует tab-bar/tab management).
  - Автозагрузчик биндов из org: гарантировать, что он загружается и синхронизирует ключи (реализовано, проверить поведение для tty/EXWM).
  - CAPE keybindings и consult-yasnippet (реализовано, проверить).

2. Существенные расширения (средний приоритет)
  - consult-dash, consult-eglot — уже добавлены; убедиться, что они доступны через Nix и работают.
  - avy, expand-region, projectile, treemacs, yasnippet — добавить в provided-packages и дать бинды из про-клавиши.org.
  - pro/малую-механизацию (про-малую-механизацию.el) — механизм добавления биндов в keys.el — очень удобен для пользователя; перенести как optional utility.

3. Низкий приоритет (опционально)
  - Разные экспериментальные UI-скрипты и мелкие утилиты (например opencode wrappers, aide scripts) — оставить в ~/pro.

План миграции (пошагово)
1. Атомарные изменения: подготовить и применить патчи в порядке:
  1) Nix: гарантировать что перечисленные пакеты в modules/pro-users-nixos.nix и nix/provided-packages.nix соответствуют списку нужных пакетов (consult-dash, consult-eglot, consult-yasnippet, corfu, cape, kind-icon, avy, expand-region, yasnippet, projectile, treemacs, ripgrep, fd, findutils). Уже сделано частично — проверить и дополнить.
 2) Emacs: перенести и адаптировать следующие файлы/фрагменты из ~/pro:
    - про-графическую-среду-ядро.el: exwm default simulation keys и macro exwm-input-set-keys (скопировать только simulation/mapping часть).
    - про-малую-механизацию.el: скрипт для добавления биндов в ~/.emacs.d/keys.el (как optional utility).
    - про-быстрый-доступ.el: дополнительные consult расширения (consult-ag, consult-dash уже добавлен), pro/consult-find helpers (если ещё остаются отличия).
    - про-режим-бога.el: полезные глобальные бинды help-map (опционально).
 3) Keybindings: убедиться, что loader (pro/клавиши-из-org.el) корректно обрабатывает все таблицы и применяет бинды как global + exwm + modes (tty fallback). Если нет — доработать loader (учесть экранирование, escape sequences для tty).
 4) UI/Completion: проверить corfu/cape настройку в emacs/base/modules/ui.el и откорректировать corfu-auto-* параметры по ~/pro (corfu-count, corfu-auto-delay, corfu-preselect). Включить corfu-history, kind-icon margin formatter.
 5) Tests: добавить e2e assertions (scripts/emacs-e2e-assertions.el) для ключевых функций: consult-find, consult-buffer, consult-dash, consult-eglot, pro/consult-find, pro/consult-buffer, pro/клавиши-из-org.

Точные файлы для правок и примеры
- Nix: modules/pro-users-nixos.nix (providedPackages + extraPackages), nix/provided-packages.nix, system-packages.nix (rg/fd/findutils)
- Emacs: emacs/base/modules/nav.el (consult + xref + embark), emacs/base/modules/ui.el (corfu/cape), emacs/base/modules/consult-helpers.el (pro/consult-find/pro/consult-buffer), emacs/base/modules/completion-keys.el, emacs/base/init.el (org keys loader), new optional modules:
  - emacs/base/modules/exwm-sim.el (перенос из ~/pro про-графическую-среду-ядро.el: simulation keys macro)
  - emacs/base/modules/key-utils.el (про-малую-механизацию helper)

План выполнения (сроки/атомарность)
- Шаг A (1 commit): Добавить exwm-sim module с simulation keys и макросом exwm-input-set-keys. Тест: запуск EXWM (или просто проверка функции exwm-input-set-keys defined).
- Шаг B (1 commit): Добавить key-utils (про-малую-механизацию), и expose command для записи в keys.el. Тест: pro/add-key helper и проверка записи.
- Шаг C (1 commit): Обновить Nix packages (provided-packages.nix + modules/pro-users-nixos.nix). Тест: home-manager switch / nixos-rebuild, и проверить (executable-find "rg"), featurep reports.
- Шаг D (1 commit): Проверки e2e: расширить scripts/emacs-e2e-assertions.el с новыми asserts.
- Каждое изменение — отдельный commit, с понятным сообщением, без force pushes.

Критерии готовности
- Все ключевые команды (C-x b, C-x C-f, M-s d, C-c C-., C-c o f, C-c y y, M-g g, M-SPC) работают как в ~/pro.
- Nix предоставляет необходимые пакеты и утилиты (rg/fd/find).
- pro/клавиши-из-org корректно применяет бинды для GUI и tty (fallbacks).
- Документы обновлены: docs/plans/emacs-right-alt-grab.md и этот план в docs/plans.

Риски и mitigations
- Неполная поддержка Wayland: exwm-sim и grab‑helper рассчитаны на X11; документировать это и оставить Wayland как "best effort".
- Внутренние API пакетов могут измениться: все non-essential фичи подключать лениво и с guard'ами (require ... nil t and fboundp checks).

Следующие шаги (конкретно сейчас)
1. Я внедрю emacs/base/modules/exwm-sim.el (копирую simulation keys macro и таблицу simulation keys из ~/pro/среда/про-графическую-среду-ядро.el, адаптирую namespace и guard'ы).
2. Я внедрю emacs/base/modules/key-utils.el (про-малую-механизацию helper) с defensive API.
3. Обновлю tests: scripts/emacs-e2e-assertions.el добавлю проверки для новых функций.
4. Применю изменения в Nix (если уже не применены) и зафиксирую коммиты.

Заключение
- Предложенный подход — прагматичный компромисс: переносим высокоэффективные инструменты и helper'ы, оставляя экспериментальную и персональную часть в ~/pro. Это даёт знакомый, продуктивный UX, не жертвуя воспроизводимостью.

Автор плана: OpenCode (автоматизированная миграция)

Углублённый диалектический анализ и конкретизация (расширение плана)
=================================================================

Цель углублённого анализа: дать исчерпывающий, практический список того, что именно
перенести из ~/pro в pro-nix (файлы, функции, бинды), почему это важно, и как это
сделать с минимальным риском. Фокус — на рабочих элементах UX (навигация, автодополнение,
EXWM-интеграция, keybindings), которые реально используются ежедневно.

1) Структура и источники знания
- Исходный набор: ~/pro — это зрелая, персональная конфигурация; в ней много мелких
  утилит и хаков, которые имеют смысл в рабочей среде пользователя.
- Целевой набор: pro-nix — репозиторий, управляющий конфигурацией для нескольких
  машин; требования: воспроизводимость, модульность, минимальная зависимость от
  локального окружения, ясные интерфейсы (defun/defcustom), и безопасные fallbacks.

2) Что именно посмотреть и почему (поля внимания)
- Навигация: consult/*, vertico, orderless, marginalia, embark/embark-consult,
  consult-* расширения (dash, eglot, yasnippet, ripgrep/ag). Эти пакеты обеспечивают
  основной UX поиска/перехода.
- Автодополнение: corfu + cape + kind-icon + yasnippet + consult-yasnippet. CAPE
  backends и corfu делают in-buffer completion удобным.
- Проекты/поиск по проекту: consult-ripgrep, consult-find, pro-project helpers,
  projectile. pro/consult-find wrapper нужен, чтобы C-x C-f начал с project root.
- EXWM: simulation keys, rename/management hooks, systemtray integration — это
  важные плюсы для тех, кто использует Emacs как WM.
- Keybindings: централизованный loader из org (про-клавиши-из-org.el) — главная
  точка синхронизации биндов, нужен повсеместно.
- Малые удобства: pro-tabs, pro-tabs integrations, pro-mалую-механизацию (автомат
  добавление биндов), pro-ui cosmetics.

3) Что ещё переносить (конкретно) — приоритетный список и мотивация
- А. Высокий приоритет — перенос без обсуждения
  1. EXWM: файлы
     - ~/pro/среда/про-графическую-среду-ядро.el → emacs/base/modules/exwm-core.el (load-safe)
     - ~/pro/среда/про-графическую-среду-окна.el → emacs/base/modules/exwm-windows.el
     - ~/pro/среда/про-графическую-среду-трей.el → emacs/base/modules/exwm-tray.el
     Почему: EXWM поведение (simulation keys, rename, hooks) критично для тех,
     кто работает в EXWM; перенос уменьшит разрыв UX и багов.

  2. Key loader и keys.org: уже есть, но нужно убедиться в интеграции с
     pro-nix — перенести ~/pro/организация/про-клавиши-из-org.el и обеспечить
     его загрузку при старте (с защитой на отсутствие файлов).

  3. pro-tabs (вкладки): ~/pro/среда/про-внешний-вид.el содержит use-package pro-tabs.
     Если команда использует табы — перенести pro-tabs и его настройки (icons,
     bindings). Альтернатива — сделать pro-tabs optional module.

  4. pro-mалую-механизацию: utility для добавления биндов в keys.el (key-utils) —
     переносится как opt-in helper; делает управление биндами простым для пользователей.

- B. Средний приоритет — перенести если есть ресурсы
  1. pro-быстрый-доступ.el: содержит много consult-related helpers (consult-ag,
     consult-dash, consult-eglot, consult-yasnippet) — можно вынести полезные
     функции и оставить остальное.
  2. pro-интеграции: pro-интеграция с Eglot, pro/consult-eglot (если в pro уже есть
     расширенные команды) — перенести ключевые бинды.
  3. UI cosmetics: pro/внешний-вид — pro-tabs, golden-ratio, treemacs bindings,
     icons; перенести как опциональные настройки.

- C. Низкий приоритет — сделать optional или оставить в ~/pro
  1. Эксперименты, специфичные для пользователя: opencode wrappers, aide scripts,
     персональные утилиты.

4) Конкретная карта файлов (source → target) — предварительный список
- ~/pro/среда/про-графическую-среду-ядро.el → emacs/base/modules/exwm-core.el
- ~/pro/среда/про-графическую-среду-окна.el → emacs/base/modules/exwm-windows.el
- ~/pro/среда/про-графическую-среду-трей.el → emacs/base/modules/exwm-tray.el
- ~/pro/среда/про-внешний-вид.el (pro-tabs части) → emacs/base/modules/pro-tabs.el (opt-in)
- ~/pro/инструменты/про-малую-механизацию.el → emacs/base/modules/key-utils.el (opt-in)
- ~/pro/навигация/про-быстрый-доступ.el → emacs/base/modules/pro-quick-access.el (перенести только helper-части: consult-* calls, pro/consult-buffer functions)
- ~/pro/организация/про-клавиши-из-org.el → (использовать уже) emacs loader (загружать при старте)

5) Дизайн-инварианты и код-стандарты при переносе
- Ленивые загрузки: require 'feature nil t и fboundp checks перед define-key/setq
- Один источник правды для биндов: nav.el как primary place; exwm-sim.el для EXWM-related keys
- Опциональность: модули, специфичные для пользователя, должны быть загружаемыми
  через defcustom или module flag (pro.emacs.extraModules), чтобы не влиять на
  воспроизводимость по умолчанию.
- Документировать каждое отличие: вставлять короткий comment с ссылкой на исходный файл в ~/pro.

6) Тесты и валидация (детализированная)
- Unit/Smoke assertions (scripts/emacs-e2e-assertions.el): проверить наличия функций и биндов
  - (fboundp 'consult-find) (fboundp 'consult-buffer) (fboundp 'consult-dash) (fboundp 'consult-eglot)
  - (lookup-key vertico-map (kbd "TAB")) → vertico-next
  - (lookup-key eglot-mode-map (kbd "C-c C-.")) → consult-eglot-symbols
  - проверка темы: (featurep 'pro-tabs) если pro-tabs enabled
- Integration tests: headless Emacs run to call pro/клавиши-из-org and verify representative key binds
- Manual smoke tests (checklist): [list as before]

7) CI / PR policy
- Каждый этап — отдельный PR/commit
- PR должен включать:
  - краткое описание: какие файлы перенесены и почему
  - список тестов (как запускать e2e assertions)
  - дефолтный fallback: как отключить новую фичу (defcustom или comment)

8) Меры по откату и безопасному развёртыванию
- Каждый модуль имеет флаг (defcustom pro-enable-EXWM t); если false — модуль
  не активируется и файл загружается только для чтения.
- Перед изменениями Nix: создавать snapshot профиля или писать README с командами восстановления.

9) План работ (конкретнее, с шагами и примерными commit messages)
- Commit 1: "emacs: add exwm-core/win/tray modules (simulation keys, hooks)" — include small unit tests
- Commit 2: "emacs: add key-utils (pro-mалую-механизацию) and document usage" — add CLI helper
- Commit 3: "emacs: integrate pro-quick-access helpers (consult helpers)" — move pro/consult-buffer variants
- Commit 4: "nix: extend provided packages with avy/expand-region/yasnippet/projectile/treemacs" — update modules/pro-users-nixos.nix and nix/provided-packages.nix
- Commit 5: "tests: add e2e assertions for consult/corfu/exwm-keybindings" — extend scripts

10) Темы для обсуждения перед миграцией (вопросы)
- Нужна ли 1:1 миграция pro-tabs (включая icons), или делаем opt-in? (рекомендация: opt-in)
- Какой набор пользователей (machines) должен сразу получить новые пакеты через Nix?
- Должен ли Right‑Alt grab helper быть включён по умолчанию или опционально? (рекомендация: opt-in, docs+systemd unit)

Резюме
- Я углубил анализ и описал конкретную карту переносимых файлов, требования к тестам, стратегию постепенной миграции и безопасные меры отката. Следующий шаг — подготовить конкретные патчи по шагам Commit1..Commit5 и сделать PR/commit'ы по одному заданию за раз.

Если подтверждаете, я подготовлю патчи для Commit 1 и Commit 2 (exwm modules и key-utils) и отложу их до вашего разрешения на commit. Пока — никаких коммитов без вашего сигнала.

Новый обязательный принцип реализации
------------------------------------------------
В целях соответствия правилам репозитория и требованию "глобальные клавиши только через keys", все новые глобальные бинды должны регистрироваться не напрямую через global-set-key в модулях, а через центральный ключевой загрузчик (про-клавиши-из-org.el) либо добавляться в keys.el через key-utils API. Модули должны экспонировать только локальные, mode‑specific keymaps и дать рекомендованные записи для keys.org. Это означает:

- Модули не должны вызывать `global-set-key` на top-level. Вместо этого:
  - Предоставлять plist/alist `:pro-keys` с парами ("C-c x" . function-symbol) или
  - Регистрировать mode-map bindings локально (define-key в mode-map) — это ок.
  - Для глобальных биндов: записывать рекомендации в `docs/keys-suggestions.org` и/или добавлять строки в keys.org через key-utils helper при opt-in.

- Loader pro/клавиши-из-org.el остаётся single source of truth: он читает ~/pro/про-клавиши.org (или пользовательский путь), ставит глобальные бинды и EXWM бинды и создаёт tty fallback. Все изменения глобальных биндов идут туда.

Этот подход сохраняет репо правила: модули не меняют глобальную клавишную атмосферу без централизованного механизма и делает клaвиши повторяемыми и управляемыми пользователем.

Детализованный план реализации (реализация заново по правилам репозитория)
----------------------------------------------------------------------
Подготовка: все файлы и изменения делаются в emacs/base/modules; Nix-пакеты регистрируются через nix/provided-packages.nix и modules/pro-users-nixos.nix.

Commit A — exwm core (high priority)
- File: emacs/base/modules/exwm-core.el
  - Реализовать: default simulation keys table (pro/exwm-default-simulation-keys), safe macro pro/exwm-input-set-keys, functions pro/exwm-load-core, pro/exwm-wm-mode-safe, pro/exwm-import-display-env.
  - Expose defcustom pro-exwm-enable (default nil). If pro-exwm-enable is non-nil AND exwm present, module will call pro/exwm-load-core and setup hooks. Otherwise module only defines functions/vars.
  - В модуле не определять глобальные бинды; вместо этого добавить alist `pro/exwm-suggested-global-keys` describing suggested global bindings for keys.org loader (see формат ниже).
  - Tests: unit test for macro expansion, ensure pro/exwm-default-simulation-keys is defined.

Commit B — exwm windows + tray (medium)
- Files: emacs/base/modules/exwm-windows.el, emacs/base/modules/exwm-tray.el
  - Реализовать window rename hooks, exwm-manage hooks, system tray init function. All hooks should be added under guard (when (fboundp 'exwm-...)).
  - Provide `pro/exwm-suggested-exwm-keys` for exwm-specific global keys.

Commit C — key-utils (low risk)
- File: emacs/base/modules/key-utils.el (we added skeleton)
  - Implement API: pro/add-keybinding-to-file (already added), pro/remove-keybinding-from-file, pro/list-keys-in-file. Add dry-run and confirm flag.
  - Provide helper to append recommended keys from modules automatically when user opts-in: pro/import-module-keys (module-name &optional force) which reads module's :pro-keys data and writes to pro/keys-file.
  - Tests: simulate writing to temp file and parse contents.

Commit D — pro-quick-access (consult helpers) (already partial)
- File: emacs/base/modules/pro-quick-access.el
  - Reimplement selected helpers from ~/pro/навигация/про-быстрый-доступ.el but follow rules:
    - No global-set-key at top level. Expose function list and add `:pro-keys` alist for suggested bindings.
    - Ensure pro/consult-find wrapper and pro/consult-buffer are present (we have these). Add docstrings and tests.

Commit E — pro-tabs (opt-in)
- File: emacs/base/modules/pro-tabs.el
  - Re-implement minimal pro-tabs integration: enable icons if kind-icon present, bind recommended keys in `pro/pro-tabs-suggested-keys` alist, and make module enable only when defcustom pro-pro-tabs-enable is t.

Commit F — completion defaults and CAPE keys
- Files: emacs/base/modules/completion-keys.el (we added), emacs/base/modules/ui.el (existing)
  - Finalize corfu/cape defaults in ui.el (corfu-auto, corfu-cycle, corfu-count, corfu-preselect). Ensure all require calls are guarded.
  - Ensure completion-keys.el contains only suggested global keys via `:pro-keys` alist and binds only when loaded explicitly (or via keys loader). Keep global-set-key only inside with-eval-after-load 'cape but prefer to store suggestions and let keys loader write them to keys.el.

Commit G — package availability (Nix)
- Files: nix/provided-packages.nix, modules/pro-users-nixos.nix, system-packages.nix
  - Ensure packages added as earlier: consult-dash, consult-eglot, consult-yasnippet, corfu, cape, kind-icon, avy, expand-region, yasnippet, projectile, treemacs, ripgrep, fd, findutils. Implement guard in home-manager template for missing packages and report.

Commit H — loader improvements
- File: emacs/base/modules/org-keys-loader.el (refactor of existing pro/клавиши-из-org.el)
  - Make loader robust, idempotent, and able to import :pro-keys alists from modules automatically when pro/import-module-keys is called.
  - Add API: pro/register-module-keys module-name keys-alist which modules can call to publish key suggestions without writing global-set-key. The loader will store these suggestions in memory and can write them to keys.el on user command.
  - Add UI: pro/keys-import-module-list (interactive) to select modules to import suggested keys.
  - Tests: run loader on sample keys.org and ensure global-map changed only via loader.

Commit I — docs and tests
- Add docs/keys-suggestions.org (list recommended keys exported by modules). Add tests to scripts/emacs-e2e-assertions.el verifying loader behavior.

Format for module suggested keys (contract)
- Each module that wants to suggest global keys defines a var `pro/<module>-suggested-keys` as an alist of ("KEY" . symbol-or-description) and registers it via `pro/register-module-keys` in with-eval-after-load when module loaded. Example:

  (defvar pro/exwm-suggested-keys
    '( ("s-q" . exwm-reset)
       ("s-<return>" . pro/exwm-launch-term) )
    "Suggested global keys for EXWM; not applied by module itself.")

  (when (fboundp 'pro/register-module-keys)
    (pro/register-module-keys 'exwm pro/exwm-suggested-keys))

Notes on enforcement: modules must not call `global-set-key` at top level; CI test will flag any such occurrences by grepping for `global-set-key` outside keys loader or tests.

Rollback and safety
- Provide `pro/remove-module-keys` to remove imported keys; loader should keep a provenance file (~/.config/emacs/keys.provenance.el) mapping lines to modules for safe revert.

Заключение и следующий шаг
- Я подготовлю патчи, реализующие Commit A..C (exwm-core, exwm-windows/tray skeletons, key-utils) following these rules. После их внедрения мы пройдём Commit D..I.

Скажите: разрешаете ли начать с Commit A (exwm-core) и Commit C (key-utils) одновременно? Я подготовлю патчи и применю их.

Итоговая упрощённая политика ключей (emacs-keys.org — единственный источник)
--------------------------------------------------------------------------
- Все глобальные клавиши хранятся только в Org: repo/emacs-keys.org (системный слой)
  и ~/.config/emacs/keys.org (пользовательский слой). Модули глобальные бинды не
  назначают (никаких `global-set-key` вне модуля keys.el).
- Модули реализуют только функциональность (consult/corfu/exwm и т.д.) и локальные
  бинды (mode-map) если нужно. Вся «форма» клавиш — в Org.
- Лёгкий линт (CI) гарантирует отсутствие `global-set-key` в модулях.

Практические шаги под эту политику:
- Обновить emacs-keys.org, добавить/уточнить «важные и удобные» бинды (навигация, поиск,
  completion/CAPE, consult‑yasnippet, LSP/eglot, avy/expand-region, projectile, treemacs,
  EXWM секция).
- В nav.el оставить только поведенческие настройки consult (preview, xref handlers),
  никаких глобальных ремапов find-file→consult-find и т.п. — всё это в Org.
- В completion-keys.el — убрать глобальные бинды, оставить описание (коммент/доки), что
  нужные комбинации уже есть в emacs-keys.org.
- В key-utils — не писать Emacs Lisp в файл, а при необходимости открывать keys.org
  пользователю; основной путь — руками править Org и вызывать M-x pro-keys-reload.
