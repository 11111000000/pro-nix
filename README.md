# NixOS конфигурация

Этот репозиторий содержит portable-конфигурацию NixOS для `pro`.

Что здесь есть:
- `flake.nix` - точка входа для сборки системы
- `configuration.nix` - основная конфигурация NixOS
- `hardware-configuration.nix` - параметры, сгенерированные для железа
- `system-packages.nix` - список системных пакетов
- `local.nix` - локальные переопределения конкретного хоста, не хранится в git
- `modules/pro-users.nix` - общие пользователи и Home Manager база
- `modules/pro-desktop.nix` - X11/desktop defaults and fonts
- `modules/nix-cuda-compat.nix` - обходные совместимости Nix/CUDA

Профиль `pro` уже встроен в основной конфиг: все пользователи машины получают общую базу Emacs, EXWM как опцию и Samba-шару по имени хоста.

## Как это работает

Конфигурация описывает систему декларативно: вы меняете `.nix`-файлы, а затем пересобираете систему. После пересборки NixOS применяет новые настройки, пакеты и сервисы.

Основная сборка идёт через flake:

```bash
sudo nixos-rebuild switch --flake .#pro
```

Если нужно просто собрать систему без немедленного применения:

```bash
sudo nixos-rebuild build --flake .#pro
```

Если хотите пересобрать и сразу загрузиться в новое поколение после перезагрузки:

```bash
sudo nixos-rebuild boot --flake .#pro
```

## Как вносить изменения

1. Измените нужный `.nix`-файл.
2. Проверьте синтаксис и сборку.
3. Примените конфигурацию командой `nixos-rebuild switch`.

Полезная проверка перед применением:

```bash
sudo nixos-rebuild test --flake .#pro
```

## Полезные команды

Показать доступные поколения:

```bash
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system
```

Откатиться на предыдущее поколение можно из меню загрузчика или через `nixos-rebuild switch --rollback`.

## Примечания

- Имя хоста задаётся в `local.nix`.
- `local.nix` игнорируется git и может содержать hostname, Samba, hardware overrides и прочие локальные настройки.
- Если меняется железо, обновите `hardware-configuration.nix` через `nixos-generate-config`.
- После правок в пакетах или сервисах всегда делайте пересборку, иначе изменения не применятся.
