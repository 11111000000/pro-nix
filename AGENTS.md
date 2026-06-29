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
local-templates/           # Шаблоны конфигов агентов (см. §10)
  pi/{mcp,models,settings}.json
  pi/skills/<name>/SKILL.md
  opencode/opencode.json
  opencode/skills/<name>/SKILL.md
docs/agent-configs.md      # Подробная документация по pi/opencode (см. §10)
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
git status && git diff
# Полная проверка: только по явному запросу пользователя — `just flake-check`
# (долго, eval всей huawei-конфигурации). Для быстрой валидации используй
# `nix eval .#nixosConfigurations --apply builtins.attrNames` (мгновенно).
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

# Сетевой стек (pro-hosts / pro-network / pro-ssh-clients / headscale)
just network-contract
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

#### Политика `just switch` по субмодулям

`just switch` (и `scripts/helper-switch.sh` под ним) **по умолчанию не обновляет**
субмодули с remote. Решение принимается в три фазы:

| Состояние | Действие |
|-----------|----------|
| передан флаг `update-submodules` / `sync` (через `just switch <host> update-submodules`) | `git submodule update --remote --merge` для каждого submodule (sequential, 20s fetch + 10s merge timeout; при сбое WARNING, идём дальше) |
| `PRO_NIX_NO_SUBMODULE_UPDATE=1` (escape hatch) | ничего не делаем |
| submodules не инициализированы (`git submodule status` показывает `-`) | `git submodule update --init --recursive` — первичная загрузка |
| submodules уже инициализированы | **ничего не делаем**, используем то, что лежит в `submodules/` |

Мотивация: `just switch` запускается часто (после каждой правки в `.nix`/`.el`).
Дёргать `git submodule update --remote` на каждый switch — лишний сетевой round-trip
и потенциальные конфликты с локальными правками в submodule (dirty check
заставлял switch падать). Теперь `just switch` — дешёвая операция, а
явное обновление делается только когда нужно.

Ручное обновление (без switch):
```bash
just sync-submodules
# или напрямую:
./scripts/sync-submodules.sh
```

#### Настройка субмодулей по умолчанию (HTTPS)

Процесс создания новой среды:

1. Инициализируйте субмодули (HTTPS по умолчанию):
   ```bash
   git submodule update --init --recursive
   # или просто запустите `just switch` — он сам сделает --init --recursive,
   # если submodules не инициализированы.
   ```

2. Для пользователей, у которых есть SSH-ключ для репозитория, можно локально
   переопределить URL субмодуля на SSH для возможности пуша:
   ```bash
   git config submodule.submodules/agent-shell-hud.url git@github.com:11111000000/agent-shell-hud.git
   git submodule sync
   # Если нужен свежий код сразу:
   just sync-submodules
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
# Входящие ссылки в .gitmodules уже HTTPS.
# Обновить submodules до свежих main/master:
just sync-submodules
# или
git submodule update --remote --merge
# `just switch` (без флагов) НЕ обновляет submodules — только собирает Nix.
# Если нужно обновить перед сборкой:
just switch <host> update-submodules
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

### 6e. Ellama + llm: upstream ELPA tarball gone

Upstream nixpkgs `pkgs.emacsPackages.llm` (в nixpkgs 25.11) запинен на
`llm-0.27.2.tar` в ELPA mirrors. Этот tarball **удалён** с зеркал (HTTP 404
на `elpa.gnu.org`, `melpa.org`, и пр.) — пакет удалён по retention policy.
Результат: build `emacs-llm-0.27.2` падает с `cannot download llm-0.27.2.tar`
на каждом из зеркал. Это **drift upstream ELPA**, не вина нашего кода.

Наш `nix/emacs-recipes/llm.nix` обходит проблему: `fetchFromGitHub`
`ahyatt/llm@745f9b10…` (HEAD от 2026-06-28) + обычный `mkDerivation`
без `elpa2nix`. Это работает потому что ellama 1.29+ просто требует
`llm 0.31+`, а upstream HEAD уже совместим.

**Alphabetic-order gotcha** (см. `nix/overlays/emacs-extra.nix`):
attrset literal `localRecipes` оценивается **по алфавиту** — `ellama`
оценивается раньше `llm`. Если ellama recipe берёт
`super.emacsPackages.llm`, получит upstream broken, а не наш patched.
Решение — патчим llm в `let patchedLlm = super.callPackage ...` **до**
`localRecipes`, и в `ellama = ...` явно пробрасываем
`emacsPackages_llm = patchedLlm` (плюс остальные buildInputs).

Также учтите, что ellama.el `require`-ит `plz-event-source` и
`plz-media-type` напрямую — это **отдельные** emacsPackages, не
подкаталоги plz. Их надо явно передавать в recipe как
`emacsPackages_plz_event_source` / `emacsPackages_plz_media_type`.

Симптомы и диагностика:

- `error: cannot download llm-0.27.2.tar from any mirror` → upstream
  ELPA tarball gone. Решение: убедитесь, что `nix/emacs-recipes/llm.nix`
  подключён в `nix/overlays/emacs-extra.nix`, и `llm = patchedLlm` стоит
  через `let binding`.
- `error: Cannot open load file: llm` (но build deps включают llm)
  → alphabetic-order gotcha; ellama recipe получает upstream llm. См.
  выше.
- `error: Cannot open load file: plz-event-source` или
  `plz-media-type` → не добавлены в `buildInputs` ellama recipe. Это
  отдельные packages, не subdir of plz.

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

## 9. Сетевая модель (LAN + mesh + SSH-нейминг)

Сеть в pro-nix строится из **трёх независимых слоёв**, каждый со своей
ответственностью. Не смешивать в одном модуле.

| Слой | Модуль | Что делает | Когда работает |
|------|--------|------------|----------------|
| LAN-обнаружение | `modules/pro-network.nix` (Avahi + nssmdns + resolved) | рекламирует SSH, резолвит `host.local` | только в одной L2-сети |
| Mesh | `modules/headscale.nix` (control plane) + будущий `modules/pro-tailnet.nix` (клиенты) | стабильные IP/имена вне LAN, NAT-traversal | всегда, где есть интернет |
| SSH-нейминг | `modules/pro-ssh-clients.nix` (генерирует `ssh_config.d/pro.conf`) | `ssh host` без DNS | для каждой сети свой алиас (см. ниже) |

### Single source of truth: `pro.hosts`

`modules/pro-hosts.nix` объявляет **реестр** известных машин. Все остальные
сетевые модули читают `config.pro.hosts.<name>`. Не дублируй `roles`,
`sshUser` или `tailnet` в нескольких местах — это источник рассинхрона.

```nix
pro.hosts.station = {
  sshUser = "az";
  roles = [ "server" "headscale" "lan-gw" "nfs" "tor" ];
  tailnet = "station";
};
```

### Алиасы SSH: один блок на кандидат

Сгенерированный `ssh_config.d/pro.conf` для каждого хоста из `pro.hosts`
выпускает **один `Host` блок на кандидат** (а не один блок с
автоматическим failover'ом — OpenSSH так не умеет). Пользователь
сам выбирает алиас под текущую сеть.

| Алиас | HostName | Маршрут |
|-------|----------|---------|
| `<name>` | `<name>.<base_domain>` (headscale FQDN) | tailnet — primary, требует `headscale` + MagicDNS |
| `<name>.local` | `<name>.local` | mDNS / LAN — работает только в одной L2-сети |
| `<name>.<base_domain>` | `<name>.<base_domain>` | tailnet FQDN (тот же, что и primary, явный алиас) |
| `<addr>` (если задан в `pro.hosts`) | `<addr>` | статический IP / публичный DNS |
| `<name>-onion` (если задан `onion`) | v3 hidden service | tor — torsocks ProxyCommand |

`Host <name>` (без суффикса) — primary: `HostName` указывает на самый
приоритетный кандидат (обычно tailnet FQDN), и `ssh <name>` идёт
напрямую туда. Bare shortname `<name>` в DNS/mDNS не резолвится —
это by design, иначе пришлось бы синхронизировать `/etc/hosts` со
всеми машинами кластера.

Каждый `Host` блок несёт свой `ConnectTimeout` (опция
`pro.sshClient.connectTimeout`, default 5s), `IdentityFile` и
`IdentitiesOnly yes` — то есть набирать `ssh -i ...` руками
не нужно, ключ подставляется автоматически.

**Не дублируй** эти блоки в `~/.ssh/config`. Override имеет смысл
только для специфичных overrides (отдельный пользователь, нестандартный
порт, jump-host) — для базового подключения модуль уже всё настроил.

### Где включать headscale

**Только на одном хосте** с ролью `headscale` и `lan-gw` (по умолчанию —
`station`). На всех остальных хостах `headscale.enable = lib.mkForce false`
явно (см. `hosts/*/configuration.nix`). Забытое `headscale.enable = true`
на ноутбуке — частая причина «случайного» control plane.

### Антипаттерны

- ❌ Хардкодить IP в ssh-конфиге. Доверься `pro.hosts` + tailnet-FQDN.
- ❌ `services.resolved.llmnr = "false"` (строка). Должен быть **bool**.
  NixOS-тип `enum` принимает только определённые значения; `false`
  истинно нужно писать без кавычек.
- ❌ Включать `services.tailscale.enable` глобально — требует auth-key,
  ломает `nixos-rebuild` без секрета. Включай через `pro.tailnet.enable`
  (после того, как модуль появится).

### Быстрая проверка после правки

```bash
# Синтаксис и базовые атрибуты
nix-instantiate --parse modules/pro-hosts.nix
nix-instantiate --parse modules/pro-network.nix
nix-instantiate --parse modules/pro-ssh-clients.nix
nix eval --json .#nixosConfigurations.station.config.pro.hosts \
  --apply builtins.attrNames
# Должно вывести: [ "cf19" "station" "huawei" "vm" ]

# Контракт
just network-contract
```

## 7. Запреты (кратко)

| Нельзя | Почему |
|--------|--------|
| `lib.mkDefault` для обязательных пакетов | Вытесняется обычным присвоением — пакеты молча пропадают |
| Глобальный zoom через `set-face-attribute` | Меняет шрифт во всех буферах |
| `(define-key global-map …)` в модулях | Глобальные биндинги — только в `emacs-keys.org` |
| `nixos-rebuild switch` в CI | Только eval/build, без применения |

## 10. Agent configs (pi + opencode)

**Краткая шпаргалка.** Полная версия — `docs/agent-configs.md`.

| Что | Где | Как деплоится |
|-----|-----|---------------|
| Шаблоны конфигов (source of truth) | `local-templates/{pi,opencode}/` | коммитятся |
| Активация на новой машине | `modules/pro-agent-configs.nix` (`home.activation.pro-agent-configs-deploy`) | `nixos-rebuild switch` |
| Shell-аналог (для не-NixOS и быстрого форса) | `scripts/deploy-agent-configs.sh` | `just deploy-agents` |
| npm-пакеты (pi-mcp-adapter и др.) | `local-templates/pi/settings.json` → `~/.pi/agent/settings.json` | `scripts/install-pi-packages.sh` |
| Удобный entry-point | `just switch-with-agents HOST` | deploy + install + switch в одном рецепте |
| Документация для модели по EMCP | `local-templates/*/skills/emacs-emcp/SKILL.md` | копируется как `skills/emacs-emcp/SKILL.md` |

**Железные правила:**

- `local-templates/` — единственный источник правды. **Правь шаблон, не деплой.**
- `copy_if_missing` — никогда не перезаписывает существующий файл. Чтобы форсировать обновление — `rm` → `just deploy-agents`.
- `pi install npm:…` — мерджит, не теряет существующие поля settings.json.
- `pi-mcp-adapter` ставится **отдельно** через npm (не через Nix), потому что нет воспроизводимой сборки.
- EMCP — это HTTP MCP-сервер на 127.0.0.1:38913. Стартует лениво из Emacs. Если `pi` показывает 0 тулов у `emcp` — `emacsclient -e '(pro-emcp-server-start)'`.
- В `pi` MCP доступен через **прокси-тулзу** `mcp({tool:…, args:…})`. В `opencode` MCP-тулзы **прямые** (`emcp_apropos` и т.п.). Не путай.
