# План: рефакторинг system-packages.nix и исправление ssh/bash

## Контекст
После последних изменений при `nixos-rebuild switch` на хосте `huawei` потеряны критичные бинарники: `bash` и `ssh` отсутствуют в `/run/current-system/sw/bin/`. В результате система остаётся нерабочей (нет интерпретатора, нет SSH).

## Причина
Анализ git history показывает, что в коммите `912ec6b` и дальнейших (`a060ca6`) была изменена стратегия формирования `environment.systemPackages` в `configuration.nix`:

```nix
# До (вырывается из system-packages.nix, где был явный список)
# environment.systemPackages = with pkgs; [ ... ];

# После (2026-04)
environment.systemPackages = lib.mkForce (with pkgs; [ bashInteractive openssh just jq ]
  ++ (import ./system-packages.nix { inherit pkgs emacsPkg; enableOptional = false; }));
```

**Проблема**: `system-packages.nix` **не импортирует `bashInteractive` и `openssh`**, а полагается на то, что они добавляются в `configuration.nix`. Однако при импорте модулей в `system-packages.nix` (`pkgs.writeShellScriptBin`, `stdenv.mkDerivation`, `with pkgs`) используется исходный `pkgs`, который **не содержит `bashInteractive` и `openssh` в момент выполнения импорта**, поскольку `system-packages.nix` не является NixOS-модулем и не получает доступ к `config`/`pkgs` из `mkHost`. В результате итоговый `lib.mkForce` получает только `[bashInteractive openssh just jq]` и **ничего из списка из system-packages.nix**.

Детали:
- `system-packages.nix` — это чистая Nix-функция (не модуль), которая возвращает список пакетов.
- `pkgs.writeShellScriptBin` и другие производные derivations создаются **из того `pkgs`, который передан в аргументах**.
- `with pkgs` внутри `system-packages.nix` использует `pkgs` из входного параметра.
- Если в `pkgs` нет `bash`/`openssh` — они не появятся в итоговом списке.

Вывод: `system-packages.nix` **не включает `bashInteractive` и `openssh`**, и при `lib.mkForce` эти пакеты перезаписывают любой вклад модулей. Таким образом модули, которые раньше добавляли `bash`/`openssh` через `lib.mkDefault`, теряют свои вклады.

## Устранение корневой причины

### Шаг 1: Проверка текущего поведения (Diagnosis)
```bash
# Собрать конфиг и посмотреть итоговый список пакетов
nix build .#nixosConfigurations.huawei.config.system.build.toplevel --no-link --impure --show-trace \
  2>&1 | head -n 1 || true

# Проверить, какие пакеты попадают в environment.systemPackages (через nix-instantiate)
nix-instantiate --eval -E '
  let
    cfg = import ./configuration.nix {
      config = {}; pkgs = import <nixpkgs> { system = "x86_64-linux"; }; emacsPkg = import <nixpkgs> { system = "x86_64-linux"; }.emacs;
    };
  in cfg.environment.systemPackages
' | head -n 20
```

**Ожидаемый результат (сейчас)**: в итоговом списке будет `[bashInteractive openssh just jq]` и список производных из `system-packages.nix`. Однако в комментах указано, что после switch эти пакеты отсутствуют, значит либо скрипты не создаются, либо `system-packages.nix` не выводит список.

### Шаг 2: Исправление system-packages.nix (minimal)
Добавить `bashInteractive` и `openssh` в `system-packages.nix` напрямую, чтобы они гарантированно попадали в итоговый список:

```nix
  # Основной набор пакетов (строка 278)
  (if enableOptional then optionalPackages else []) ++ [
  kbd
  bashInteractive          # ← добавить
  openssh                  # ← добавить
  # ... остальной список
```

**Альтернатива**: убрать `lib.mkForce` и использовать `lib.mkDefault`+`lib.mkAfter`, чтобы модули и `system-packages.nix` могли суммировать пакеты.

### Шаг 3: Рефакторинг configuration.nix → модули
```
modules/
├── system-boot.nix         #-loader.kernelsysctl
├── system-network.nix      #hostname.mDNS, firewall (base)
├── system-time.nix         #timezone.locale, sudo
├── system-hardware.nix     #input, Bluetooth, power, xserver
├── system-nix.nix          #nix.settings, flakes, gc
├── system-gaming.nix       #steam
├── system-services.nix     #udisks2, guix, flatpak, portal
├── system-packages-base.nix #systemPackages (with bashInteractive, openssh)
├── system-fonts.nix        #fonts.packages, fontconfig
├── system-etc-files.nix    #environment.etc.* конфиги
├── system-systemd.nix      #oomd, nix-daemon, polkit
├── system-environment.nix  #environment.variables
└── system-final.nix        #stateVersion + last-resort overrides
```

## План разработки (диалектическийmethod → Лао Цзы)

### Этап 1: Абстракция → Противоречие
**Тезис**: все пакеты объявлены в одном месте (`system-packages.nix`), что упрощает поддержку.
**Антитезис**: при этом `environment.systemPackages = lib.mkForce ...` перекрывает весь вклад модулей. Когда модули добавляют пакеты через `lib.mkDefault`, они не попадают в итог, так как `lib.mkForce` применяется после всех импортов.
**Синтез**: `environment.systemPackages` задаётся на уровне `configuration.nix` как **сумма** базовых пакетов + вклад модулей. Базовые пакеты (bashInteractive, openssh) описываются в модуле `system-packages-base.nix`.

### Эталонная архитектура
```
configuration.nix ──► импорт модулей ──► каждый модуль добавляет пакеты через lib.mkDefault ──► итог
```

**Критерий успеха**: `environment.systemPackages` **не использует `lib.mkForce`**. Все модули могут добавлять пакеты без потерь.

## Рекомендованная последовательность шагов

### A) Диагностика и тестирование (неделя)
1. Проверить, какие пакеты сейчас собираются в `environment.systemPackages`.
2. Создать простой smoke test `tests/smoke-system.nix` для валидации ключевых программ.
3. Запустить `nix flake check` и исправить все замечания.
4. Протестировать `nixos-rebuild build --flake .#huawei` локально.

### B) Исправление system-packages.nix (1–2 дня)
1. Добавить `bashInteractive` и `openssh` в `system-packages.nix` (строка 278).
2. Убедиться, что производные пакеты (`opencodeCmd`, `pythonCmd`, etc.) работают.
3. Проверить, что при сборке `huawei` в `/run/current-system/sw/bin/` есть `bash` и `ssh`.

### C) Рефакторинг configuration.nix на модули (1 неделя)
- Создать `modules/system-packages-base.nix` с базовыми пакетами.
- Перенести секции конфигурации в отдельные модули, сохраняя текущие значения.
- Заменить `lib.mkForce` на `lib.mkDefault`+`lib.mkMerge`, чтобы пакеты суммировались.

### D) CI/Smoke test (1 день)
- Добавить тест `nix-build -A checks.x86_64-linux.smoke-system`.
- Запускать в CI перед `nixos-rebuild`.

### E) Миграция (только после тестов)
1. Обновить `configuration.nix`, убрать дублирование.
2. Протестировать `just switch` на `huawei` в VM (если есть).
3. Зарепортить изменения.

## Таблица изменений (только для ревью, не вносить пока)

| Файл | Что | Причина |
|------|-----|---------|
| `system-packages.nix` | добавить `bashInteractive` и `openssh` в основной список | устранить потерю в `lib.mkForce` |
| `modules/system-packages-base.nix` | (новый) базовые пакеты | разделение ответственности |
| `modules/system-network.nix` | (новый) net settings | модульность |
| `configuration.nix` | убрать `lib.mkForce`, импортировать модули | согласованность |

## Шаблон для new modules
```nix
# modules/system-packages-base.nix
{ lib, pkgs, ... }:

{
  # Высокоуровневое описание: "базовые пакеты, необходимые для всех хостов"
  environment.systemPackages = lib.mkDefault (
    with pkgs;
    [ bashInteractive openssh just jq git curl wget htop ]
    # + производные модуля, если нужно
  );
}
```

## Следующие шаги (когда согласованы основы)
1. Запустить `nix build .#check-all --show-trace`.
2. Применить patch (добавить bashInteractive/openssh в system-packages.nix).
3. Собрать и проверить `huawei` (`nix-build .#nixosConfigurations.huawei.config.system.build.toplevel`).
4. Если работает — начать модульную реорганизацию.

## Примечание для диалектического анализа
**Противоречие**: в текущей схеме `configuration.nix` и `system-packages.nix` объявляют пакеты в двух местах. Это создаёт неявное дублирование и риск потери пакетов при `lib.mkForce`.
**Решение**: единая точка сборки (модуль `system-packages-base.nix`) + `lib.mkDefault` для наследования.

---

**Версия документа**: v1.1 (2026-04-24)  
**Ответственный**: opencode-agent  
**Статус**: Diagnostics → Implementation pending
