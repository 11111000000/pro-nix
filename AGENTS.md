# AGENTS.md — Правила работы с pro-nix

Соглашения для агентов и людей. Написано по итогам реальных ошибок.

---

## 1. Карта репозитория

```
configuration.nix          # Корневой NixOS-конфиг
flake.nix                  # Flake: hosts, nixpkgs pin, checks
local.nix                  # Секреты (НЕ КОММИТИТЬ)
emacs-keys.org             # Глобальные Emacs-биндинги (код, не docs)
justfile                   # just switch, just build, …
modules/                   # NixOS-модули (sessions, profiles, services, packages)
hosts/                     # Хост-специфичные конфигурации
emacs/base/modules/        # Emacs Lisp модули (pro-*.el)
emacs/base/site-init.el    # Загрузчик модулей Emacs
```

## 2. NixOS: приоритеты пакетных списков

**Императив:** подключённый модуль обязан добавить свои пакеты в итоговую сборку.

```nix
# ✅ Обязательные пакеты — plain assignment (списки склеиваются)
environment.systemPackages = with pkgs; [ pavucontrol playerctl ];

# ⛔ НЕ ИСПОЛЬЗУЙ lib.mkDefault для обязательных пакетов
```

`lib.mkDefault` имеет приоритет 100 — любое обычное присвоение в другом модуле
молча вытесняет эти пакеты. Уместен только для опциональных наборов, которые
пользователь может захотеть переопределить.

## 3. Emacs: биндинги

**`emacs-keys.org` — это исполняемый код.** Каждая строка таблицы = реальный
глобальный биндинг, который парсит `pro-keys.el`. Не комментируй, не «документируй»
этот файл — редактируй его как код.

| Секция | Клавиша | Команда | Описание |
|--------|---------|---------|----------|
| UI     | C-x M-c | pro/reload-config | Перечитать весь конфиг |

- `s-` = super, `S-` = shift, `C-` = control, `M-` = meta
- Глобальные биндинги живут **только** здесь. Модули регистрируют предложения
  через `pro/register-module-keys`, которые потом мержатся в этот файл.
- После изменения: `M-x pro-keys-reload` (или перезапуск Emacs).

## 4. Emacs: модули и зона влияния

- Модули: `emacs/base/modules/pro-*.el`, override: `~/.config/emacs/modules/`
- Префикс `pro-` в именах, `(provide 'pro-name)` в конце, идемпотентность.

### Zoom — buffer-local

`C-=` / `C-+` / `C--` / `C-0` меняют шрифт **только в текущем буфере**
через `text-scale-*`. Не используй `set-face-attribute 'default nil`
для zoom — это глобальная операция, ломающая все буферы.

### Soft reload после `just switch`

Изменения в Emacs-модулях не применяются автоматически после NixOS-rebuild:

| Действие | Команда | Когда |
|----------|---------|-------|
| Быстрый reload | `C-x M-c` / `M-x pro/reload-config` | После правки модулей, ключей, UI |
| Полный reload  | `C-u M-x pro/reload-config` | Если что-то сломалось |
| Перезапуск     | Закрыть/открыть Emacs | Крайний случай |

## 5. Git: чистота

- Формат коммита: `тип: описание` (`pkg`, `emacs`, `keys`, `fix`, `nix`, `chore`)
- Один коммит = одна логическая правка. Не смешивай Nix и Emacs.
- **Не коммить:** `local.nix`, `.crew/`, `*.elc`, `result*`, `logs/` (уже в .gitignore)

### Перед пушем

```bash
nix flake check
git status && git diff
```

## 6. Проверка изменений

```bash
# NixOS: проверить, что пакет попал в сборку (без rebuild)
nix eval --json .#nixosConfigurations.cf19.config.environment.systemPackages | jq -r '.[]' | rg <пакет>

# Emacs: headless-тесты
just headless-tests && just headless-report

# Emacs: pending-биндинги
# M-x pro-keys-report-pending
```

## 7. Запреты (кратко)

| Нельзя | Почему |
|--------|--------|
| `lib.mkDefault` для обязательных пакетов | Вытесняется обычным присвоением — пакеты молча пропадают |
| Глобальный zoom через `set-face-attribute` | Меняет шрифт во всех буферах |
| `(define-key global-map …)` в модулях | Глобальные биндинги — только в `emacs-keys.org` |
| `nixos-rebuild switch` в CI | Только eval/build, без применения |
