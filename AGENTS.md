# AGENTS.md — Правила работы с pro-nix

Этот файл описывает соглашения, которые агенты (и люди) должны знать
перед тем, как трогать репозиторий. Написано по итогам реальных ошибок.

---

## 1. Структура репозитория

```
configuration.nix          # Корневой NixOS-конфиг (импортирует flake.nix + модули)
flake.nix                  # Flake: hosts, nixpkgs pin, check-all, devShell
local.nix                  # Секреты / локальные override (НЕ КОММИТИТЬ)
emacs-keys.org             # Глобальные Emacs-биндинги (НЕ документация — это код)
modules/                   # NixOS-модули: services, sessions, profiles, packages
hosts/                     # Хост-специфичные конфигурации (cf19, huawei, desktop)
emacs/base/modules/        # Emacs Lisp модули (pro-*.el)
emacs/base/site-init.el    # Загрузчик модулей Emacs (аналог init.el для системы)
scripts/                   # Утилиты: switch.sh, emacs-sync.sh, и т.д.
justfile                   # Makefile-заменитель: just switch, just build, и т.д.
.crew/                     # pi-crew runtime state (gitignored)
```

## 2. NixOS-модули: пакеты и приоритеты

### Правило: plain assignment для обязательных пакетов

Если модуль подключён — его пакеты ДОЛЖНЫ попасть в итоговую сборку.
Используй plain assignment:

```nix
environment.systemPackages = with pkgs; [
  pavucontrol
  playerctl
];
```

### НЕ используй lib.mkDefault для обязательных пакетов

`lib.mkDefault` имеет низкий приоритет (100). Если любой другой модуль
делает обычное присвоение `environment.systemPackages = ...` (приоритет по умолчанию),
mkDefault-пакеты **молча выпадают** из итоговой сборки.

Это уже приводило к багу: pavucontrol пропал с cf19, потому что его пакетный
список был завёрнут в mkDefault, а host-профиль перезаписал список обычным
присвоением.

### Когда mkDefault уместен

- Опциональные наборы пакетов, которые пользователь может захотеть переопределить.
- Модули-«предложения» (suggestions), которые легко отключить.

## 3. Emacs-биндинги: emacs-keys.org — это код, не документация

`emacs-keys.org` — это Org-таблица, которую парсит `pro-keys.el` и превращает
в реальные глобальные keymap-биндинги в Emacs. Это не docs, не примеры.

### Формат строки

| Секция | Клавиша | Команда | Описание |
|--------|---------|---------|----------|
| UI     | s-S-R   | pro/reload-config | Перечитать весь конфиг |

- Секция: произвольная категория (UI, EXWM, Навигация, ...)
- Клавиша: Emacs-нотация (`C-=`, `s-r`, `S-TAB`, `s-S-R`)
  - `s-` = super (Win/Meta на клавиатуре)
  - `S-` = shift
  - Комбинации: `s-S-R` = Super+Shift+R
- Команда: имя функции (символ) в Emacs Lisp
- Описание: краткое пояснение на русском или английском

### Как добавить биндинг

1. Добавить строку в `emacs-keys.org` в соответствующую секцию.
2. После изменения файла пользователь должен выполнить:
   - `M-x pro-keys-reload` (или `C-c k`) — перечитает файл и применит биндинги.
   - Или перезапустить Emacs.

### НЕ создавай дублирующие биндинги в .el-файлах

Глобальные биндинги живут ТОЛЬКО в `emacs-keys.org`.
Модули могут регистрировать «предложения» через `pro/register-module-keys`,
которые потом мержатся в emacs-keys.org.

## 4. Emacs-модули: система загрузки

- Модули лежат в `emacs/base/modules/pro-*.el`.
- Пользовательские override — в `~/.config/emacs/modules/`.
- Загрузчик: `emacs/base/site-init.el` → `pro-emacs-base-start`.
- Каждый модуль должен:
  - Иметь `(provide 'pro-name)` в конце.
  - Использовать префикс `pro-` в именах функций/переменных.
  - Быть идемпотентным (повторный `load` не ломает сессию).

## 5. Soft reload после `just switch`

После применения NixOS-конфига (`just switch cf19`) изменения в Emacs-модулях
НЕ вступают в силу автоматически. Пользователь должен:

1. **Быстрый reload** (достаточно в 90% случаев):
   - `M-x pro/reload-config` или `s-S-R`
   - Перезагружает все модули, ключи, шрифты, UI-настройки.

2. **Полный reload** (если что-то сломалось):
   - `C-u M-x pro/reload-config`
   - Повторно запускает `pro-emacs-base-start` (аналог init.el).

3. **Перезапуск Emacs** (крайний случай):
   - Закрыть и открыть Emacs заново.

### Реализация

Функция `pro/reload-config` в `emacs/base/modules/pro-reload.el`.
Она безопасно перезагружает модули (ignore-errors / condition-case),
перечитывает ключи, восстанавливает epistemology-state, применяет UI.

## 6. Emacs zoom: buffer-local, не глобальный

Клавиши `C-=` / `C-+` / `C--` / `C-0` вызывают:
- `pro-ui-zoom-in` — увеличить шрифт **в текущем буфере**
- `pro-ui-zoom-out` — уменьшить шрифт **в текущем буфере**
- `pro-ui-zoom-reset` — сбросить масштаб **в текущем буфере**

Реализация использует `text-scale-increase` / `text-scale-set` (buffer-local),
А НЕ изменение глобального `pro-ui-font-height` + `pro-ui-apply-fonts`.

## 7. Git-соглашения

### Коммиты

- Формат: `тип: краткое описание`
- Типы: `pkg`, `emacs`, `keys`, `fix`, `chore`, `cleanup`, `nix`, `modules`
- Один коммит = одна логическая правка. Не смешивай Nix- и Emacs-изменения.

### Ветка

- Основная: `main`
- Пуш: `git push` после проверки

### Что НЕ коммитить

- `local.nix` — локальные секреты/override
- `.crew/` — pi-crew runtime (gitignored)
- `*.elc` — скомпилированный Emacs Lisp (gitignored)
- `result`, `result-*` — симлинки nix-build (gitignored)
- `logs/` — логи (gitignored)

### Перед пушем

1. `nix flake check` — быстрая проверка
2. `git status` — нет ли случайных файлов
3. `git diff` — sanity check изменений

## 8. Проверка изменений (validation)

### NixOS

```bash
# Быстрая проверка синтаксиса
nix flake check

# Проверить конкретный хост (без применения)
nix eval --json .#nixosConfigurations.cf19.config.environment.systemPackages | jq -r '.[]' | rg pavucontrol

# Полная проверка (не в CI)
just switch cf19
```

### Emacs

```bash
# Headless-тесты
just headless-tests
just headless-report

# Проверка pending-биндингов
# В Emacs: M-x pro-keys-report-pending
```

## 9. Anti-patterns (чего НЕ делать)

- ❌ `environment.systemPackages = lib.mkDefault [...]` для пакетов, которые
  обязаны быть в системе при подключении модуля.
- ❌ Глобальное изменение шрифта через `set-face-attribute 'default nil`
  из функций zoom — это меняет шрифт во ВСЕХ буферах.
- ❌ Создание глобальных Emacs-биндингов в .el-файлах модулей
  (исключение: minibuffer/vertico map и специфичные mode-map).
- ❌ Редактирование `emacs-keys.org` как если бы это была документация —
  это исполняемый код, каждая строка таблицы = реальный биндинг.
- ❌ Запуск `nixos-rebuild switch` в CI/scripts без подтверждения.
- ❌ Коммит `.nfs*`, `.elc`, `result*` и другого build-мусора.

## 10. Ключевые файлы — краткий справочник

| Файл | Что это | Когда трогать |
|------|---------|---------------|
| `emacs-keys.org` | Биндинги Emacs | Добавить/изменить hotkey |
| `emacs/base/modules/pro-compat.el` | Совместимость / fallback | Новые fallback-функции, zoom |
| `emacs/base/modules/pro-reload.el` | Soft reload | Изменить логику перезагрузки |
| `emacs/base/modules/pro-ui.el` | UI: шрифты, темы, курсор | Визуальные настройки |
| `emacs/base/modules/pro-keys.el` | Система клавиш | Парсинг org, apply-pending |
| `modules/session-audio.nix` | Аудио-модуль | pipewire, pavucontrol |
| `modules/session-exwm.nix` | EXWM session | EXWM-пакеты, xsession |
| `configuration.nix` | Корневой NixOS-конфиг | Импорты, общие настройки |
| `hosts/cf19/configuration.nix` | Профиль cf19 | Хост-специфика cf19 |
| `justfile` | Команды | Добавить рецепт |
