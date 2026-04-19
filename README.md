# Pro NixOS + Emacs

Этот репозиторий содержит две связанные части:

1. NixOS-конфигурацию `pro` для машинных профилей.
2. Портативный Emacs-слой, который можно подключать отдельно на любой машине с Nix и Home Manager.

## Быстрый старт

### NixOS

Новая машина:

```bash
sudo nixos-generate-config
sudo nixos-rebuild switch --flake .#default
```

Готовый хост:

```bash
# Применение конфигурации хоста
just switch <HOST>  # thinkpad, desktop, cf19, huawei
```

Интерактивная установка:

```bash
./bootstrap/install.sh
```

### Portable Emacs

С Home Manager:

```nix
{
  imports = [ /path/to/repo/emacs/home-manager.nix ];
  pro.emacs.enable = true;
  pro.emacs.gui.enable = false;
}
```

Без Nix, в текущий `~/.emacs.d`:

```bash
./scripts/emacs-sync.sh ~/.emacs.d
```

Перед синхронизацией старый `~/.emacs.d` автоматически переименуется в backup с timestamp.

Если использовать новый путь по умолчанию, скрипт ставит `~/.config/emacs` и создаёт `~/.emacs.d` как симлинк на него. Для NixOS Home Manager тоже использует этот путь напрямую.

Логи headless-проверки:

```bash
./scripts/emacs-headless-report.sh
```

## Проверки

```bash
nix flake check
nix run .#check-all
just headless
just headless-report
```

Если `nix flake check` каждый раз заново тянет зависимости, проверьте, что `flake.lock` закоммичен и что входы не переопределяются через нечёткие URL. В этом репозитории `home-manager` и `nixpkgs` должны быть зафиксированы в лока.

## Команды

- `just install` - интерактивная установка NixOS-хоста
- `just install-emacs` - синхронизация портативного Emacs в текущий `~/.emacs.d`
- `just install-plain` - то же самое для plain `.emacs.d`
- `just flake-check` - проверка flake (всех или конкретного хоста)
- `just check-all` - сборка всех машин
- `just build <HOST>` - сборка конфигурации (без применения)
- `just switch <HOST>` - применение конфигурации
- `just test <HOST>` - тестовый запуск конфигурации

## Что здесь есть

- `flake.nix` - точка входа для NixOS-профилей и явной проверки всех машин
- `configuration.nix` - общая системная база NixOS
- `hosts/` - машинные профили
- `emacs/home-manager.nix` - отдельный Emacs-профиль для NixOS, WSL, Termux и обычного Linux
- `emacs/base/` - общая Emacs-база
- `modules/pro-users.nix` - общая пользовательская политика для NixOS
- `modules/pro-users-*.nix` - платформенные адаптеры Emacs-слоя
- `scripts/` - установочные и диагностические сценарии
- `justfile` - команды для сборки и тестов
- `ENVIRONMENT.md` - рабочий порядок и проверки

## Примечания

- `flake.nix` больше не обязан проверять все хосты по умолчанию.
- Платформенная Emacs-обвязка отделена от общей базы, чтобы тот же конфиг можно было использовать в WSL и Termux.
