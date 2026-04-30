# Вклад в pro-nix

`CONTRIBUTING.md` описывает практический процесс изменения репозитория. Общая
карта проекта находится в `README.md`; публичные контракты — в `SURFACE.md`;
инварианты и решения — в `HOLO.md`.

Цель правил: сохранять воспроизводимость, композиционность модулей и
проверяемость поведения. Изменение считается завершённым только тогда, когда его
Intent ясен, Surface impact определён, Proof запущен или явно указан, а риск
миграции описан для стабильных поверхностей.

## Перед началом

Прочитайте документы в этом порядке:

1. `AGENTS.md` — локальная политика агентов и инженерные ограничения.
2. `SURFACE.md` — публичные контракты и Proof-команды.
3. `HOLO.md` — инварианты, решения и проверочная модель.
4. `README.md` — общая карта репозитория.
5. `CONTRIBUTING.md` — этот процесс изменения.

Сформулируйте один доминирующий Intent. Если задача затрагивает несколько
подсистем, сначала сузьте её до одного проверяемого изменения.

## Change Gate

Каждое содержательное изменение проходит через Change Gate. Для небольших
локальных правок его можно держать в PR-описании. Для изменений, затрагивающих
публичные контракты, Change Gate обязателен.

Формат (шаблон для PR):

```text
Intent: <одной строкой опишите цель изменения>
Pressure: <Bug | Feature | Debt | Ops>
Surface impact: (none) | touches: <SURFACE item(s)> [FROZEN/FLUID]
Proof: tests: <команды или файлы, подтверждающие изменение>

## Краткое описание

- <пункт 1 — что сделано>
- <пункт 2 — зачем>
- <пункт 3 — результат>
- <пункт 4 — риски или ограничения>

## Проверки

- [ ] Я обновил `SURFACE.md`, если менялось публичное поведение.
- [ ] Я добавил или обновил Proof для `[FROZEN]` поверхностей.
- [ ] Я запустил `nix fmt`.
- [ ] Я запустил `nix flake check`.
- [ ] Я запустил `./tools/surface-lint.sh`.
- [ ] Я запустил `./tools/holo-verify.sh`.

## Migration (заполняется только если затронут `[FROZEN]`)

- Impact: <что меняется>
- Strategy: <additive_v2 | feature_toggle | break_with_window>
- Window/Version: <окно или версия>
- Data/Backfill: <что нужно перенести или "n/a">
- Rollback: <безопасный откат>
- Tests:
  - Keep: <что сохраняется>
  - Add: <что добавляется>
```

## Surface First

Публичное поведение меняется в порядке `Surface -> Proof -> Code -> Verify`.

- Если правка не меняет наблюдаемое поведение, укажите `Surface impact: none`.
- Если правка меняет FLUID-поверхность, обновите `SURFACE.md` и Proof при
  необходимости.
- Если правка меняет FROZEN-поверхность, сначала зафиксируйте контракт,
  Migration и Proof, затем меняйте код.
- Если добавляется новый публичный entrypoint, опция, systemd-сервис или команда,
  добавьте контрактную запись или объясните, почему это внутренняя деталь.

## Правила письма

Документация, комментарии и docstring в этом репозитории пишутся на русском
языке.

Пишите как контракт:

- цель;
- инварианты;
- ограничения;
- эффекты;
- проверки.

Не пишите расплывчатые формулы вроде «улучшить», «удобно», «красиво», если их
нельзя проверить. Если термин может быть понят по-разному, дайте короткое
определение.

## Правила Nix

- Модуль должен вносить вклад, а не финализировать систему.
- В общих модулях предпочитайте `lib.mkDefault`, композицию списков и локальные
  опции.
- `lib.mkForce` допустим на host-уровне, когда нужно окончательно зафиксировать
  политику.
- Не формируйте модульные списки через прямую зависимость от
  `config.environment.systemPackages`, если это создаёт рекурсию или скрытую
  связанность.
- Крупные Nix-файлы разделяйте по ответственности.
- Для `systemd.services.<name>.serviceConfig.ExecStart` используйте явные пути к
  скриптам или простые shell-команды. Не вставляйте `pkgs.writeShellScriptBin`
  внутрь строки `ExecStart` так, чтобы derivation неявно превращался в путь.

Для изменений в `environment.systemPackages` обязательны дополнительные проверки:

```bash
nix --extra-experimental-features 'nix-command flakes' eval --json .#nixosConfigurations.<host>.config.environment.systemPackages
bash tests/contract/unit/09-system-packages-eval.sh
```

## Правила Emacs Lisp

- Одна функция выполняет одну задачу.
- Публичная функция имеет docstring с кратким контрактом.
- Побочные эффекты локализованы и описаны.
- Изменения поведения сопровождаются ERT-тестом или явным объяснением, почему
  тест не применим.
- Длинные монолитные функции разбиваются на helpers, если это улучшает границы
  ответственности.

Базовая проверка загрузки модуля:

```bash
emacs --batch --eval "(require 'pro-nix)"
```

Используйте конкретный модуль вместо `pro-nix`, если меняли другой файл.

## Проверки

Минимальный набор для документационных и контрактных изменений:

```bash
./tools/surface-lint.sh
./tools/holo-verify.sh
```

Базовая flake-проверка:

```bash
nix flake check
```

Для проверки всех хостов через flake app:

```bash
nix run .#check-all
```

Для NixOS-хоста:

```bash
nix build .#nixosConfigurations.<host>.config.system.build.toplevel
```

Для live-активации сначала проверьте вычислимость профиля пакетов:

```bash
nix --extra-experimental-features 'nix-command flakes' eval --json .#nixosConfigurations.<host>.config.environment.systemPackages
```

Если preflight падает, `nixos-rebuild switch` запрещён до исправления причины.

## Pull Request Checklist

Перед PR проверьте:

1. Intent сформулирован одной строкой.
2. Change Gate заполнен.
3. `Surface impact` соответствует фактическому изменению.
4. Для `[FROZEN]` поверхности есть Migration и Proof.
5. Секреты, токены и machine-local state не попали в diff.
6. Запущены релевантные Proof-команды.
7. Если проверка не запускалась, причина указана явно.

## Безопасные патчи

Делайте минимальный diff, который закрывает Intent.

- Один PR — одна доминирующая цель.
- Один файл — одна ответственность.
- Не смешивайте экспериментальный код с каноническими модулями.
- Не исправляйте соседние проблемы без отдельного Intent.
- Не добавляйте backward compatibility без конкретного внешнего потребителя,
  сохранённых данных или явного требования.

Если изменение влияет на доступ, сеть, ключи, systemd units или live-активацию,
добавьте canary и rollback в PR-описание.

## Canary и rollback

Для операционных изменений опишите:

- где запускается canary;
- какие команды подтверждают успех;
- какие логи проверяются;
- как вернуть прежнее состояние;
- какой риск остаётся после rollback.

Пример для pro-peer key sync:

```bash
sudo /etc/ops-pro-peer-canary.sh --input /tmp/test-authorized_keys.gpg --out /var/lib/pro-peer/authorized_keys
sudo /etc/ops-pro-peer-sync-keys.sh --input /tmp/test-authorized_keys.gpg --out /var/lib/pro-peer/authorized_keys
sudo cp /var/lib/pro-peer/authorized_keys.bak.<timestamp> /var/lib/pro-peer/authorized_keys
sudo chown root:root /var/lib/pro-peer/authorized_keys
sudo chmod 600 /var/lib/pro-peer/authorized_keys
```

## Секреты и локальные данные

В репозиторий нельзя добавлять:

- приватные ключи;
- токены API;
- незашифрованные credentials;
- локальные state-файлы;
- артефакты сборки и временные дампы.

Если изменение требует секрета, опишите operator-managed механизм: sops/age,
локальный файл вне git, host-specific overlay или другой утверждённый канал.

## Полезные команды

```bash
git status --short
./tools/surface-lint.sh
./tools/holo-verify.sh
./tools/mkforce-lint.sh
./tools/generate-mkforce-json.sh
./tools/generate-options-v2.sh
nix flake check
nix run .#check-all
```

## Эскалация

Если изменение затрагивает несколько подсистем, FROZEN-поверхность,
авторизацию, сеть, live-активацию или миграцию данных, согласуйте план до
реализации. Если владелец недоступен, откройте issue или draft PR с Change Gate,
Migration и предполагаемым Proof.

Фокус проекта — не скорость изменения, а безопасная эволюция проверяемой системы.
