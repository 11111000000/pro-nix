# Pro-Nix Environment

Домашняя NixOS конфигурация с Emacs разработкой.

## Быстрый старт

### 1. Создайте новую среду

```bash
# Клонировать репозиторий
git clone <repo-url> pro-nix
cd pro-nix

# Инициализировать субмодули (по умолчанию HTTPS для всех)
git submodule update --init --recursive
```

### 2. Базовые проверки

```bash
# Синтаксис конфигурации
nix-instantiate --parse configuration.nix

# Проверить flake
nix flake check
```

### 3. Разработка (HTTPS)

```bash
# Перезагрузить NixOS с актуальными субмодулями
sudo nixos-rebuild switch --flake "git+file://$(pwd)?submodules=1#<hostname>"

# Обновить Emacs после изменений в модулях
C-x M-c  # в Emacs
# или
M-x pro/reload-config
```

### 4. Производственное развёртывание (SSH для пуша)

```bash
# Сменить все субмодули на SSH (если у вас есть права на пуш)
just submodules-ssh

# Перезагрузить систему
sudo nixos-rebuild switch --flake "git+file://$(pwd)?submodules=1#<hostname>"
```

## Управление субмодулями

### Субмодули по умолчанию (HTTPS)

- Все субмодули используют HTTPS по умолчанию для работы без SSH-ключей
- Субмодуль `agent-shell-hud` был изменён с SSH на HTTPS в `.gitmodules`
- HTTPS обеспечивает чтение (клонирование), но без возможности пуша

### Если вам нужен SSH для пуша

```bash
# Изменить конкретный субмодуль на SSH локально
git config submodule.submodules/agent-shell-hud.url git@github.com:11111000000/agent-shell-hud.git
git submodule sync
git submodule update --remote --merge
```

### Сменить все на SSH

```bash
# Преобразовать все HTTPS-субмодули в SSH (только если у вас есть SSH-ключ)
./scripts/submodules-ssh.sh
```

### Вернуться обратно к HTTPS

```bash
# Восстановить исходную конфигурацию .gitmodules
cp .gitmodules.backup.<timestamp> .gitmodules

# Обновиться до HTTPS
git submodule sync && git submodule update --remote --merge
```

## Управление через `just`

| Команда | Что делает |
|---------|--------------|
| `just switch <HOST>` | NixOS-rebuild switch (обновляет субмодули автоматически) |
| `just submodules-ssh` | Преобразовать все субмодули в SSH |
| `just build <HOST>` | Nixos-rebuild build |
| `just test <HOST>` | Nixos-rebuild test |
| `just flake-check` | Nix flake check с субмодулями |

## Структура репозитория

```
configuration.nix          # Корневой NixOS-конфиг
dotfiles/                  # Включения для Home Manager (пользовательские настройки)
flake.nix                  # Flake: hosts, nixpkgs pin, checks
justfile                   # Just команды для работы с системой
local.nix                  # Секреты (НЕ КОММИТИТЬ)
modules/                   # NixOS модули (процессорные, system-package-sets, nix-*, ...)
hosts/<name>/              # Конфигурации хостов
emacs/base/                # Emacs Lisp модули (pro-*.el)
.gitmodules                # Определения субмодулей
```

## Советы и решения проблем

### Submodule не инициализирован

Если при `just switch` появляется ошибка типа:
```
fatal: '/home/az/pro-nix/submodules/acapella' does not appear to be a git repository
```

Исправьте:
```bash
git submodule update --init --recursive
just switch
```

### У вас есть SSH-ключ, но клонирование не работает

Если ваша `.gitmodules` содержит SSH URL, клонирование будет работать только
если у вас есть SSH-ключ для репозитория.

Решения:
1. **Если у вас есть SSH-ключ**: Смените все на SSH:
   ```bash
   ./scripts/submodules-ssh.sh
   ```

2. **Если у вас нет SSH-ключа**: Используйте HTTPS (по умолчанию, как реализовано)

### Изменения в Emacs не применяются после `just switch`

```bash
# Быстрый перезапуск Emacs
C-x M-c   # в Emacs
# или
M-x pro/reload-config

# Полный перезапуск (если что-то сломалось)
C-u M-x pro/reload-config
```

### Перезапуск системы

Если вам нужно перезагрузить:

```bash
# Безопасный перезапуск (рекомендуется)
sudo nixos-rebuild boot --flake "git+file://$(pwd)?submodules=1#<hostname>"
sudo reboot

# Быстрый перезапуск (рискует race condition)
sudo nixos-rebuild switch --flake "git+file://$(pwd)?submodules=1#<hostname>"
```

## AGENTS.md

Подробные правила работы с репозиторием, Submodules и Emacs приведены в
`AGENTS.md`. Используйте это в качестве руководства для:

- Редактирования и удаления мёртвого кода
- Управления Submodules
- Конвенций фиксации коммитов
- Проверки изменений
- Emacs разработки

## Связь

Для вопросов или помощи, свяжитесь с создателем.
