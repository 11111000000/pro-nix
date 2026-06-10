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
modules/                   # См. §1a — не только NixOS-модули
hosts/<name>/
  configuration.nix        # NixOS-модуль хоста
  composition.nix          # Слой пакетов: import ../../modules/system-package-sets-*.nix
emacs/base/modules/        # Emacs Lisp модули (pro-*.el)
emacs/base/site-init.el    # Загрузчик модулей Emacs
```

### 1a. Структура `modules/`

`modules/` шире, чем кажется по имени. Реальные подкатегории:

| Паттерн | Что это | Как удалять |
|---------|---------|-------------|
| `modules/pro-*.nix` | Обычные NixOS-модули | Убрать из `imports = [ … ]` в `configuration.nix` / `hosts/*/configuration.nix` |
| `modules/session-*.nix` | Оконные менеджеры / DM | То же |
| `modules/system-package-sets-*.nix` | **НЕ NixOS-модули** — функции `{ pkgs }: { somePackages = [ … ]; }`, импортируются из `hosts/*/composition.nix` | Удалить файл + `import` + `++ X.somePackages` в обоих `hosts/*/composition.nix` |
| `modules/system-*.nix` | Низкоуровневые политики (boot, systemd) | Стандартно через imports |
| `modules/nix-*.nix` (nix-cuda-compat и т.п.) | Кастомные пакеты/юниты | Стандартно |

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

Пустой `environment.systemPackages = with pkgs; [ ];` — сигнал «модуль не
дописан». Не наполнять ради наполнения, а удалить модуль целиком вместе с
импортом.

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

### Cleanup-коммиты (при удалении мёртвого кода)

Не «один большой сweep», а по домену:

- `nix: remove X` — flake.nix + `configuration.nix` + `composition.nix` + удаляемый модуль. **Один коммит**, потому что промежуточное состояние сломано.
- `chore: drop unused Y` — `conf/`, тесты, артефакты, `.gitignore`.
- `emacs: …` — только `.el`.

Заголовок: `nix: <что>`. В теле — список всех затронутых файлов и почему
удаляется.

## 6. Проверка изменений

```bash
# Синтаксис (после любой правки .nix)
nix-instantiate --parse <изменённый-файл.nix>

# Flake ещё живой (атрибуты резолвятся)
nix eval .#nixosConfigurations --apply builtins.attrNames

# Конкретные output'ы — ловят то, что flake show не ловит (см. §6a)
nix eval .#checks.x86_64-linux.huawei-boot.outPath
nix eval .#apps.x86_64-linux.check-all.program
nix eval .#devShells.x86_64-linux.default.shellHook

# NixOS: проверить, что пакет попал в сборку (без rebuild)
nix eval --json .#nixosConfigurations.cf19.config.environment.systemPackages | jq -r '.[]' | rg <пакет>

# Emacs: headless-тесты
just headless-tests && just headless-report

# Emacs: pending-биндинги
# M-x pro-keys-report-pending
```

### 6a. Что `nix flake check` НЕ ловит

- `cp -r ${./dir}/*` в derivation — flake eval не упадёт, build ленивый.
- `import ./path/script.py` внутри `writeShellScript` / `apps.${system}.X.program` — fail только при `nix run`.
- `toString ./missing` — то же.
- `imports = [ ./broken.nix ]` в test-файле, **не подключённом** в `flake.nix#checks` — никогда не выполнится, но `nix-instantiate --parse` пройдёт.
- Submodule-пути, на которые ссылается home-manager / fontconfig — падают только на build конкретных output'ов, не на eval flake.nix.

Контрмера: после правки flake.nix прогонять eval конкретных атрибутов (см. §6),
а не только `nix flake check`.

### 6c. Submodules и URL флейка

`nix flake check` / `nix build` с локальным флейком через `path:` URL **не
включают git-сабмодули в captured source**. Рецепты в `nix/emacs-recipes/*.nix`
берут `src = ../../submodules/<name>`; с `path:`-URL это `path does not exist`.

**Всегда** использовать `git+file://$(pwd)?submodules=1` для:
- `nix flake check` / `nix flake show`
- `nix build` / `nixos-rebuild build|switch|test`
- `nix run .#check-all`

Это уже зашито в `justfile` (recipes `build`, `test`, `flake-check`,
`check-all`) и `scripts/helper-switch.sh` (`FLAKE_REF`). Для прямого
вызова из shell — копируй URL из этих мест.

### 6d. Управление субмодулями (SSH ↔ HTTPS)

Субмодули используются по HTTPS по умолчанию для обеспечения работы всех пользователей,
даже без SSH-ключей.

#### Настройка субмодулей по умолчанию (HTTPS)

Процесс создания новой среды:

1. Инициализируйте субмодули (HTTPS по умолчанию):
   ```bash
   git submodule update --init --recursive
   # или через just:
   just switch
   ```

2. Для пользователей, у которых есть SSH-ключ для репозитория, можно локально
   переопределить URL субмодуля на SSH для возможности пуша:
   ```bash
   git config submodule.submodules/agent-shell-hud.url git@github.com:11111000000/agent-shell-hud.git
   git submodule sync
   git submodule update --remote --merge
   ```

#### Смена всех субмодулей на SSH

Скрипт `scripts/submodules-ssh.sh` преобразует все HTTPS-URL в SSH:

```bash
# Изменяет .gitmodules и обновляет субмодули до SSH
cd pro-nix
./scripts/submodules-ssh.sh
```

Результат:
- Все HTTPS URLs в `.gitmodules` преобразуются в SSH
- Субмодули обновляются с использованием SSH URLs
- Пользователи с SSH-доступом могут теперь пушить изменения
- Пользователи без SSH-доступа не могут клонировать (нужен SSH ключ)

#### Разработка с HTTPS субмодулями (рекомендуется для большинства пользователей)

```bash
# Входящие ссылки в .gitmodules уже HTTPS
# Для clone/pull работы без SSH-ключей:
git submodule update --remote --merge
# или
just switch
```

#### Изменение субмодуля на SSH в развитии

Если вам нужен SSH-доступ во время разработки (например, вы хотите отправить
вклад):

1. Измените URL субмодуля локально:
   ```bash
   git config submodule.submodules/<submodule-name>.url git@github.com:<user>/<repo>.git
   git submodule sync
   ```

2. Перейдите в субмодуль и настройте remote:
   ```bash
   cd submodules/<submodule-name>
   git remote set-url origin git@github.com:<user>/<repo>.git
   ```

3. Сделайте коммит в субмодуле, затем вернитесь в главный репозиторий:
   ```bash
   cd ..
git add submodules/<submodule-name>
git commit -m "<submodule>: switch to ssh remote"
   ```

#### Копирование субмодулей с SSH обратно в HTTPS

Если вы перешли на SSH и хотите вернуться обратно к HTTPS (например, для
основного ветка содержимого):

```bash
# Восстановите исходную .gitmodules
cp .gitmodules.backup.<timestamp> .gitmodules

# Обновите субмодули до HTTPS
git submodule sync && git submodule update --remote --merge
```

## 8. Процесс развёртывания

### Подготовка новой среды

#### 1. Клонирование и инициализация

```bash
# Клонировать репозиторий
git clone <repo-url> pro-nix
cd pro-nix

# Инициализировать все субмодули (HTTPS режим)
git submodule update --init --recursive
```

#### 2. Базовые проверки

```bash
# Синтаксис конфигурации
nix-instantiate --parse configuration.nix

# Проверка флейка (с submoddes)
nix flake check

# Проверка целевых сборок (если нужно)
nix eval .#nixosConfigurations.cf19.config.environment.systemPackages
```

#### 3. Режим разработки (HTTPS)

```bash
# Быстрое обновление Emacs после изменений в модулях
sudo nixos-rebuild switch --flake "git+file://$(pwd)?submodules=1#<hostname>"
# Мгновенный перезапуск Emacs
C-x M-c   # в Emacs
# или
M-x pro/reload-config
```

#### 4. Производственное развёртывание (SSH для пуша)

```bash
# Сменить субмодули на SSH, если у вас есть права на пуш
just submodules-ssh

# Перезагрузить систему
just switch <hostname>

# Или вручную с sudo
sudo nixos-rebuild switch --flake "git+file://$(pwd)?submodules=1#<hostname>"
```

### Управление после развёртывания

#### Обновление субмодулей

```bash
# Обновить до удаленного main/master (HTTPS)
git submodule update --remote --merge

# Обновить конкретного субмодуля
git submodule update --remote --merge submodules/agent-shell-hud
```

#### Решение конфликтов

Если `just switch` вызывает конфликт (обычно в `local.nix`):

```bash
# Игнорировать разницу в local.nix (секреты)
git rm local.nix
# Продолжить rebase
git rebase --continue
```

#### Hard reload Emacs

```bash
# Полная перезагрузка (если что-то сломалось)
C-u M-x pro/reload-config

# Изоляция от редактора в ExWM
C-c C-c   # закрыть интернационализированный буфер
```

#### Резервное копирование перед мутацией

```bash
# Сохранить .gitmodules перед SSH переключением
./scripts/submodules-ssh.sh

# Восстановить HTTPS позже
cp .gitmodules.backup.<timestamp> .gitmodules
git submodule sync && git submodule update --remote --merge
```

### 6b. Детекторы мёртвого кода

Сигналы, по которым файл/модуль можно удалять (после ритуала ниже):

- Сам модуль/файл содержит `placeholder` / `заглушка` / `stub` / `not populated yet` / `not implemented` / `WIP` в description, имени или шапке
- `environment.systemPackages = with pkgs; [ ];` (пустой)
- Тело модуля — `lib.mkIf false { … }`
- `sha256 = "0000…000"` в `fetchurl` / `fetchFromGitHub` / `fetchTarball`
- `submodule { options = {}; }` без полей
- `enable = false;` по умолчанию + `mkIf cfg.enable` оборачивает всё тело
- Файл импортируется, но его публичные атрибуты никем не используются (`rg "<attributeName>"` пусто)

Ритуал перед удалением:

```bash
rg -l "<filename>"          # прямые импорты
rg "<attributeName>"        # использования экспортов
nix-instantiate --parse <каждый файл, который трогаем>
```

## 7. Запреты (кратко)

| Нельзя | Почему |
|--------|--------|
| `lib.mkDefault` для обязательных пакетов | Вытесняется обычным присвоением — пакеты молча пропадают |
| Глобальный zoom через `set-face-attribute` | Меняет шрифт во всех буферах |
| `(define-key global-map …)` в модулях | Глобальные биндинги — только в `emacs-keys.org` |
| `nixos-rebuild switch` в CI | Только eval/build, без применения |
