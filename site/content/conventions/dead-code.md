+++
title = "Мёртвый код"
template = "page.html"
weight = 4

[extra]
tldr = "Сигналы: placeholder, пустой systemPackages, mkIf false {}, sha256 0000, submodule без полей, enable = false default. Ритуал удаления: rg -l filename, rg attributeName, nix-instantiate --parse."

[[extra.next]]
title = "Анти-паттерны"
url = "/conventions/anti-patterns/"
+++

# Мёртвый код

Репозиторий использует несколько сигналов, чтобы обнаруживать
модули, которые нужно удалить.

## Детекторы

* Модуль содержит `placeholder`, `заглушка`, `stub`, `not
  populated yet`, `not implemented` или `WIP` в описании, имени
  или шапке.
* `environment.systemPackages = with pkgs; [ ];` (пусто).
* Тело модуля — `lib.mkIf false { ... }`.
* `sha256 = "0000…000"` в любом `fetchurl` / `fetchFromGitHub` /
  `fetchTarball`.
* `submodule { options = {}; }` без полей.
* `enable = false;` по умолчанию + `mkIf cfg.enable` оборачивает всё
  тело.
* Файл импортируется, но его публичные атрибуты никем не
  используются (`rg "<attributeName>"` пусто).
* Файл есть в `modules/`, но не в `imports` ни одного
  `configuration.nix` или `hosts/*/configuration.nix`.

## Ритуал перед удалением

```bash
# 1. Прямые импорты
rg -l "<filename>" hosts/ configuration.nix modules/

# 2. Использования публичных экспортов
rg "<attributeName>" --type nix

# 3. Синтаксис каждого файла, который трогаем
nix-instantiate --parse <каждый файл>

# 4. Полная eval-валидация
nix-instantiate --eval -E '
  let
    nixpkgs = builtins.getFlake "git+file://$PWD?submodules=1";
    cfg = nixpkgs.nixosConfigurations.cf19.config;
  in builtins.toString cfg.environment.systemPackages' | head -5
```

Шаг 4 — самый важный. Если удаление ломает eval, вернуть файл
просто (один коммит отката).

## Cleanup-коммиты

* `nix: remove X` — `flake.nix` + `configuration.nix` +
  `composition.nix` + удаляемый модуль. **Один коммит**, потому что
  промежуточное состояние сломано.
* `chore: drop unused Y` — `conf/`, тесты, артефакты,
  `.gitignore`.
* `emacs: …` — только `.el`.

Заголовок: `nix: <что>`. В теле — список всех затронутых файлов и
почему удаляется.

## Детектор в CI

`tests/contract/unit/05-mkforce-lint-test.sh` — smoke-тест, что
`tools/mkforce-lint.sh` запускается. Непосредственно dead-code
детектор в CI пока нет (TODO: добавить в `holo-verify.sh`).

## Когда НЕ удалять

* Файл — это `pro-users.nix` или `modules/searxng.nix` с
  `enable = false` по умолчанию. Это **опц.** модули, не мёртвый
  код. Хост может включить.
* Файл — `pro-emacs-rescue.nix` с `enable = mkEnableOption
  "..." // { default = true; }`. По умолчанию включён; хост может
  отключить. Это не `mkIf false {}` — это правильный паттерн.
* `pro-styles/`-подобные директории, не импортируемые, но
  перечисленные в `flake.nix` outputs как devShell-пакеты. Они
  могут быть полезны, не нужно удалять.

## Инструменты

* `rg "<pattern>"` — manual ripgrep для поиска использований.
* `nix-instantiate --parse <file>` — syntax check одного файла.
* `nix flake check` — eval всех хостов.
* `nix-instantiate --eval -E '<expr>'` — ad-hoc eval.

## Шпаргалка ритуала

```bash
# Перед удалением pro-foo.nix
rg -l "pro-foo" hosts/ configuration.nix modules/ tests/ scripts/ docs/
# Если все hits — в импортах / ссылках / тестах, не в комментариях:
rg -l "^.*pro-foo" flake.nix

# После удаления
nix-instantiate --parse flake.nix configuration.nix hosts/*/configuration.nix
nix flake check

# Проверить, что auto-gen сайт ещё строится
just site-regen
nix build ".#site"
```

## Где это уже сделано

* `modules/opencode-tui.nix` — пример маленького, полезного модуля
  с `enable = mkEnableOption`. Не мёртвый код.
* `pro-*-nix` модули, у которых `enable = false` по умолчанию +
  `mkIf` — это опц. фичи. Хосты включают через `imports`.

## Связанные

* [mkForce](conventions/mkforce.md) — per-host override паттерн
  часто использует `mkForce false` для отключения default-включённой
  опции.
* [Commit format](conventions/commit.md) — `nix: remove X` —
  правильный тип коммита для удаления.
* [Anti-patterns](conventions/anti-patterns.md) — `mkIf false {}` —
  один из анти-паттернов; это **сигнал** что модуль нужно удалить.
