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
