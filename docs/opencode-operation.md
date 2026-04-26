# OpenCode — эксплуатационная заметка

Кратко: после правок репозитория `opencode` больше не зависит от `npx @opencode/cli` в рантайме. Добавлен детерминированный Nix‑пакет и надёжный wrapper с bootstrap‑fallback. Ниже — как это работает, как проверить установку и как перейти на системную (Nix‑управляемую) версию.

## Как работает wrapper (порядок приоритета)

При запуске `opencode` используется wrapper, который выбирает исполняемый файл в следующем порядке:

1. `~/.local/bin/opencode` — если существует и исполняем, используется он.
2. `~/.opencode/bin/opencode` — если существует и исполняем, используется он.
3. `~/.local/share/opencode/opencode` — локальный кэш/bootstrap; если присутствует, используется он.
4. Если ни один из вышеперечисленных бинарей не найден — wrapper скачивает официальный релиз с GitHub Releases и распаковывает в `~/.local/share/opencode/opencode`, затем запускает его.

Для обычных CLI-вызовов wrapper передаёт argv без промежуточного `systemd-run`/`steam-run`, чтобы `opencode --help`, `opencode acp ...` и аналогичные подкоманды получали исходные параметры без подмены.

В дополнение в репозитории добавлена детерминированная Nix‑derivation (opencode_from_release) — это reproducible путь для CI и для установки через Nix (см. раздел ниже).

> Примечание: оригинальный бинарь opencode при старте может пытаться подгружать плагины/пакеты из npm. Для изолированного старта используйте `--pure`.

## Где находится кэш бинаря

- Пользовательский кэш: `~/.local/share/opencode/opencode` — туда распаковывается релиз при bootstrap.
- Локальные пути разработчика: `~/.local/bin/opencode`, `~/.opencode/bin/opencode`.
- Nix‑store пакет: derivation `opencode_from_release` (v1.14.19) добавлена в flake и может быть включена в system profile.

## Проверки (быстро)

Проверить, какой бинарь будет использован:

```
which opencode
readlink -f "$(which opencode)"
opencode --version
```

Проверить локальные места кэша:

```
ls -l ~/.local/bin/opencode ~/.opencode/bin/opencode ~/.local/share/opencode/opencode
```

Запустить smoke‑тест (в репозитории добавлен скрипт):

```
./scripts/opencode-smoke.sh
```

## Переключение на системную (Nix) версию

Если вы хотите, чтобы система использовала Nix‑управляемую версию opencode (детерминированную и воспроизводимую), выполните следующие шаги:

1. Убедитесь, что у вас нет локальных бинарей, мешающих wrapper'у. Перенесите или удалите их:

```
mv ~/.opencode/bin/opencode ~/.opencode/bin/opencode.bak  # или rm -f
mv ~/.local/bin/opencode ~/.local/bin/opencode.bak        # или rm -f
```

2. Соберите и активируйте системный профиль (пример для хоста `cf19`):

```
sudo nixos-rebuild switch --flake /path/to/pro-nix#cf19
```

(В репозитории можно также использовать `nix build .#nixosConfigurations.cf19.config.system.build.toplevel`.)

3. Проверьте, что теперь используется системный opencode:

```
which opencode
readlink -f "$(which opencode)"
opencode --version
```

Если `which` всё ещё указывает на локальную копию — удалите/переименуйте её (шаг 1) и повторите проверку.

## CI и reproducibility

- Для CI и production мы рекомендуем использовать Nix‑путь: в flake присутствует `opencode_from_release` (фиксированная версия/хэш). В CI можно вызвать `nix build .#apps.x86_64-linux.opencode-release` или включить пакет в system profile.
- В репозитории добавлен GitHub Actions workflow `./.github/workflows/opencode-smoke.yml`, который выполняет базовый smoke (скачивает/использует релиз и запускает smoke скрипт). Его можно улучшить, чтобы использовать Nix‑пакет вместо `curl`.

## Рекомендации

- Для разработчиков: удобно держать локальную cached копию (`~/.local/share/opencode/opencode`) — это ускоряет старт и даёт оффлайн fallback.
- Для production/CI: делать `nixos-rebuild switch` или включать `opencode_from_release` в системный профиль — это даёт воспроизводимость.
- Если вы хотите полностью запретить авто‑загрузку плагинов/зависимостей у opencode — запускайте с `--pure`.

## Helper (опционально)

Если нужно, можно добавить helper‑скрипт в `scripts/` который автоматизирует:
- резервное копирование локального бинаря;
- удаление локального бинаря;
- `nixos-rebuild switch --flake .#cf19`;
- проверку `opencode --version`.

Если хотите — я добавлю такой helper и включу инструкции в README.

---
Файл создан автоматически: описывает текущее поведение wrapper'а, кэш и шаги для перехода на Nix‑управляемую установку.
