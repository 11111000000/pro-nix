+++
title = "Клавиши (emacs-keys.org)"
sort_by = "weight"
template = "page.html"

[extra]
tldr = "Все 138 глобальных клавиш из `emacs-keys.org`, сгруппированных по секциям. Это исполняемый source — не документация."
+++

# Клавиши (emacs-keys.org)

<span class="gen-badge">auto-gen</span> Сгенерировано 2026-06-16 из `emacs-keys.org`.

> **Важно:** `emacs-keys.org` — это **исполняемый код**, не документация. Каждая строка в source-таблице становится реальным `global-set-key` при старте Emacs, парсится `emacs/base/modules/pro-keys.el`. Редактируйте source, а не эту страницу.

**Всего биндингов:** 138  ·  **Секций:** 24

## Указатель секций

* [AI](#ai) — 5
* [Completion](#completion) — 11
* [Docker](#docker) — 8
* [EXWM](#exwm) — 27
* [Git](#git) — 2
* [Haskell](#haskell) — 5
* [History](#history) — 12
* [LSP](#lsp) — 1
* [ORG](#org) — 1
* [Org](#org) — 1
* [Package](#package) — 7
* [Profiler](#profiler) — 5
* [Snippet](#snippet) — 1
* [Suggested](#suggested) — 4
* [Tabs](#tabs) — 5
* [UI](#ui) — 7
* [Выделение](#-) — 1
* [Дерево](#-) — 1
* [Ключи](#-) — 2
* [Навигация](#-) — 7
* [Окна](#-) — 3
* [Поиск](#-) — 10
* [Проекты](#-) — 4
* [Чат](#-) — 8

---

## AI { #ai }

| Клавиша | Команда | Описание |
|-----|---------|----------|
| `C-c a` | `pro-ai-open-entry` | Вход в AI |
| `C-c A` | `pro-agent-open` | agent-shell |
| `C-c a (hud)` | `agent-shell-hud-menu` | Пульт агента (в agent-shell-mode) |
| `C-c i (hud)` | `agent-shell-hud-info` | HUD-инфо (в agent-shell-mode) |
| `C-c r (hud)` | `agent-shell-hud-refresh` | Обновить HUD (в agent-shell-mode) |

## Completion { #completion }

| Клавиша | Команда | Описание |
|-----|---------|----------|
| `C-c o f` | `cape-file` | Источник файлов для CAPF |
| `C-c o d` | `cape-dabbrev` | Слова из буферов |
| `C-c o h` | `cape-history` | История |
| `C-c o k` | `cape-keyword` | Ключевые слова языка |
| `C-c o s` | `cape-symbol` | Символы |
| `C-c o a` | `cape-abbrev` | Аббревиатуры |
| `C-c o .` | `completion-at-point` | Вызвать CAPF |
| `C-c o p` | `completion-at-point` | CAPF (alias из pro) |
| `C-c o t` | `complete-tag` | Дополнить тег |
| `C-c o i` | `cape-dict` | Словарь |
| `C-c o l` | `cape-line` | Строка из буфера |

## Docker { #docker }

| Клавиша | Команда | Описание |
|-----|---------|----------|
| `C-c d c` | `pro-docker-containers` | Список контейнеров |
| `C-c d i` | `pro/docker-images` | Список образов |
| `C-c d v` | `pro/docker-volumes` | Список томов |
| `C-c d n` | `pro/docker-networks` | Список сетей |
| `C-c d l` | `pro/docker-logs` | Логи контейнера (-f --tail 100) |
| `C-c d e` | `pro/docker-shell` | Shell в контейнере |
| `C-c d r` | `pro/docker-restart` | Перезапустить контейнер |
| `C-c d p` | `pro/docker-prune` | docker system prune -f |

## EXWM { #exwm }

| Клавиша | Команда | Описание |
|-----|---------|----------|
| `s-r` | `exwm-reset` | Сброс окна EXWM |
| `s-w` | `tab-bar-close-tab` | Закрыть вкладку |
| `s-t` | `pro-tabs-open-new-tab` | Новая вкладка |
| `s-n` | `tab-bar-switch-to-next-tab` | Следующая вкладка |
| `s-p` | `tab-bar-switch-to-prev-tab` | Предыдущая вкладка |
| `s-N` | `tab-bar-move-tab` | Переместить вкладку вправо |
| `s-P` | `tab-bar-move-tab-backward` | Переместить вкладку влево |
| `s-T` | `tab-bar-undo-close-tab` | Восстановить вкладку |
| `s-1` | `pro-tabs-select-tab-1` | Вкладка 1 |
| `s-2` | `pro-tabs-select-tab-2` | Вкладка 2 |
| `s-3` | `pro-tabs-select-tab-3` | Вкладка 3 |
| `s-4` | `pro-tabs-select-tab-4` | Вкладка 4 |
| `s-5` | `pro-tabs-select-tab-5` | Вкладка 5 |
| `s-6` | `pro-tabs-select-tab-6` | Вкладка 6 |
| `s-x` | `pro/app-launcher` | Запуск .desktop приложения (consult) |
| `s-&` | `async-shell-command` | Запуск команды |
| `s-h` | `windmove-left` | Переместить фокус влево |
| `s-j` | `windmove-down` | Переместить фокус вниз |
| `s-k` | `windmove-up` | Переместить фокус вверх |
| `s-l` | `windmove-right` | Переместить фокус вправо |
| `s-H` | `buf-move-left` | Переместить буфер влево |
| `s-J` | `buf-move-down` | Переместить буфер вниз |
| `s-K` | `buf-move-up` | Переместить буфер вверх |
| `s-L` | `buf-move-right` | Переместить буфер вправо |
| `s-`` | `multi-vterm-project` | vterm по проекту |
| `s-~` | `eshell-toggle` | eshell toggle |
| `C-s-`` | `pro/exwm-urxvt-toggle` | Toggle urxvt в нижнем sidebar |

## Git { #git }

| Клавиша | Команда | Описание |
|-----|---------|----------|
| `C-x g` | `pro-git-status` | Статус репозитория |
| `C-c g` | `pro-git-status` | Magit status |

## Haskell { #haskell }

| Клавиша | Команда | Описание |
|-----|---------|----------|
| `C-c h l` | `pro-haskell-load-buffer` | Загрузить буфер в REPL (cabal/ghci) |
| `C-c h r` | `pro-haskell-switch-to-repl` | Переключиться на REPL |
| `C-c h f` | `pro-haskell-format-buffer` | Форматировать (fourmolu) |
| `C-c h i` | `pro-haskell-lint` | Линтер (hlint) |
| `C-c h d` | `pro-haskell-browse-haddock` | Документация символа под курсором |

## History { #history }

| Клавиша | Команда | Описание |
|-----|---------|----------|
| `C-_` | `pro-history-undo` | Шаг назад (undo) |
| `M-_` | `pro-history-redo` | Шаг вперёд (redo) |
| `C-z` | `pro-history-undo` | Шаг назад (дубль) |
| `C-M-z` | `pro-history-redo` | Шаг вперёд (дубль) |
| `C-c u` | `pro-history-time-machine` | Дерево отмен |
| `C-c z` | `pro-history-time-machine` | Дерево отмен (дубль) |
| `C-c C-,` | `goto-last-change-reverse` | К предыдущей правке |
| `C-c .` | `goto-last-change` | К последней правке |
| `C-c ,` | `goto-last-change-reverse` | К предыдущей правке |
| `<XF86Back>` | `winner-undo` | Откат раскладки окон |
| `<XF86Forward>` | `winner-redo` | Повтор раскладки окон |
| `C-c M-h` | `pro-history-transient` | Меню истории (transient) |

## LSP { #lsp }

| Клавиша | Команда | Описание |
|-----|---------|----------|
| `C-c C-.` | `consult-eglot-symbols` | Поиск символов LSP |

## ORG { #org }

| Клавиша | Команда | Описание |
|-----|---------|----------|
| `C-c K` | `pro-org-open-keys-file` | Открыть файл клавиш |

## Org { #org }

| Клавиша | Команда | Описание |
|-----|---------|----------|
| `C-c o` | `org-agenda` | Повестка |

## Package { #package }

| Клавиша | Команда | Описание |
|-----|---------|----------|
| `C-c P p` | `pro-packages-menu` | Список пакетов |
| `C-c P i` | `pro-packages-install` | Установить пакет из ELPA |
| `C-c P v` | `pro-packages-install-vc` | Установить пакет из VC |
| `C-c P u` | `pro-packages-upgrade-all` | Обновить пакеты |
| `C-c P r` | `pro-packages-refresh` | Обновить список архивов |
| `C-c P b` | `pro-packages-upgrade-built-ins` | Разрешить built-in upgrade |
| `C-c P a` | `pro-package-bootstrap-install-targets` | Установить базовые пакеты |

## Profiler { #profiler }

| Клавиша | Команда | Описание |
|-----|---------|----------|
| `<f8>` | `pro/profiler-quick` | Профиль 15 сек + автоматический отчёт |
| `C-<f8>` | `pro/profiler-start` | Запустить профайлер (CPU) |
| `S-<f8>` | `pro/profiler-stop` | Остановить профайлер |
| `M-<f8>` | `pro/profiler-report` | Открыть отчёт профайлера |
| `C-S-<f8>` | `pro/profiler-reset` | Сбросить данные профайлера |

## Snippet { #snippet }

| Клавиша | Команда | Описание |
|-----|---------|----------|
| `C-c y y` | `consult-yasnippet` | Выбор сниппета |

## Suggested { #suggested }

| Клавиша | Команда | Описание |
|-----|---------|----------|
| `C-c v y` | `pro/vterm-yank` | suggested from terminals |
| `C-c v i` | `pro/vterm-interrupt` | suggested from terminals |
| `C-c v c` | `vterm-copy-mode` | suggested from terminals |
| `C-x y` | `pro/clipboard-yank-pop` | suggested from clipboard |

## Tabs { #tabs }

| Клавиша | Команда | Описание |
|-----|---------|----------|
| `C-c t n` | `pro-tabs-open-new-tab` | Открыть новую вкладку |
| `C-c t k` | `pro-tabs-close-tab-and-buffer` | Закрыть вкладку и буфер |
| `C-c t s` | `tab-bar-switch-to-tab` | Переключиться на вкладку |
| `<C-tab>` | `pro-tabs-line-next` | Следующая tab-line вкладка (в окне) |
| `<C-S-tab>` | `pro-tabs-line-prev` | Предыдущая tab-line вкладка (в окне) |

## UI { #ui }

| Клавиша | Команда | Описание |
|-----|---------|----------|
| `C-=` | `pro-ui-zoom-in` | Увеличить шрифт |
| `C-+` | `pro-ui-zoom-in` | Увеличить шрифт (альтернатива) |
| `C--` | `pro-ui-zoom-out` | Уменьшить шрифт |
| `C-0` | `pro-ui-zoom-reset` | Сбросить масштаб |
| `C-\` | `toggle-input-method` | Переключить Emacs-IM (ru/en) |
| `C-x M-c` | `pro/reload-config` | Перечитать весь конфиг (soft reload) |
| `M-/` | `eldoc-box-help-at-point` | Подсказка под курсором |

## Выделение { #- }

| Клавиша | Команда | Описание |
|-----|---------|----------|
| `M-SPC` | `er/expand-region` | Расширение выделения |

## Дерево { #- }

| Клавиша | Команда | Описание |
|-----|---------|----------|
| `s-d` | `treemacs` | Открыть дерево |

## Ключи { #- }

| Клавиша | Команда | Описание |
|-----|---------|----------|
| `C-c k` | `pro-keys-reload` | Перезагрузить клавиши |
| `C-c M-k` | `pro-keys-reload` | Перезагрузить клавиши (alias) |

## Навигация { #- }

| Клавиша | Команда | Описание |
|-----|---------|----------|
| `C-x b` | `pro/consult-buffer` | Смена буфера (helper) |
| `C-x C-b` | `pro/consult-buffer-other-window` | Смена буфера в другом окне |
| `M-s M-s` | `consult-line-multi` | Поиск по нескольким буферам |
| `C-x y` | `consult-yank-from-kill-ring` | Вставка из истории kill-ring |
| `M-g i` | `consult-imenu` | Символы файла |
| `M-g g` | `consult-goto-line` | Переход к строке |
| `M-g g` | `avy-goto-char` | Прыжок к символу |

## Окна { #- }

| Клавиша | Команда | Описание |
|-----|---------|----------|
| `C-x +` | `pro-windows-enlarge` | Увеличить окно (C-u N — шаг) |
| `C-x -` | `pro-windows-shrink` | Уменьшить окно (C-u N — шаг) |
| `C-x =` | `pro-windows-balance` | balance-windows + golden-ratio (разово) |

## Поиск { #- }

| Клавиша | Команда | Описание |
|-----|---------|----------|
| `C-s` | `isearch-forward` | Обычный isearch (вперёд) |
| `C-r` | `pro/revert-buffer` | Revert буфера без подтверждения |
| `C-M-s` | `isearch-backward` | isearch назад (без regex) |
| `M-s s` | `consult-line` | Поиск по буферу (alias) |
| `C-c s` | `consult-ripgrep` | Поиск по проекту |
| `C-c f` | `pro/consult-find` | Поиск файла (project-aware) |
| `M-s d` | `consult-dash` | Поиск по документации |
| `C-c p s` | `pro-project-ripgrep` | Поиск в проекте |
| `C-c p f` | `pro-project-find-file` | Файл проекта |
| `C-c C-f` | `consult-find` | Поиск файла (consult) |

## Проекты { #- }

| Клавиша | Команда | Описание |
|-----|---------|----------|
| `C-c p p` | `projectile-switch-project` | Сменить проект |
| `C-c p f` | `projectile-find-file` | Файл в проекте |
| `C-c C-p` | `projectile-switch-project` | Сменить проект (alias) |
| `C-c pa` | `projectile-add-known-project` | Добавить проект |

## Чат { #- }

| Клавиша | Команда | Описание |
|-----|---------|----------|
| `C-c T` | `pro/chat-open` | Telegram |
| `C-c t o` | `pro/chat-open` | Open Telegram (telega) |
| `C-c t k` | `pro/chat-close-idle-chats` | Close idle telega chat buffers |
| `C-c t e` | `pro/chat-reload-emojis` | Reload telega emoji tables |
| `C-c t i` | `pro/chat-install` | Install telega from MELPA (fallback) |
| `C-c t s` | `pro/telega-select-chat-or-contact` | Select telega chat/contact (consult) |
| `C-c t c` | `pro/telega-select-chat-or-contact` | Select telega chat/contact (alias) |
| `C-c t u` | `pro/telega-select-chat-or-contact` | Select telega contact (C-u) |

---

## Как загружаются биндинги

1. `emacs/base/site-init.el` вызывает `pro-keys-reload` (в `emacs/base/modules/pro-keys.el`).
2. `pro-keys-reload` парсит `emacs-keys.org` как org-таблицу и применяет каждую строку как глобальный биндинг (или EXWM-специфичный, или `org-mode` локальный — третий столбец это имя секции, и парсер диспатчит соответственно).
3. Если биндинг ссылается на команду из пакета, ещё не загруженного (например, `magit-status` из `magit`), биндинг добавляется в `pro-keys-pending-bindings` и пере-применяется, когда пакет становится доступен.
4. Пользовательские override'ы лежат в `~/.config/emacs/keys.org` (тот же формат org-таблицы). Если оба файла существуют, оба парсятся по порядку; пользователь выигрывает на конфликте.

## Добавление биндинга

Отредактируйте `emacs-keys.org` напрямую — добавьте строку в нужную секцию. Сохраните файл. Внутри Emacs `M-x pro-keys-reload` (или `C-c k`). Всё. Никаких `global-set-key` в коде, никаких `use-package` `:bind` блоков не нужно.
