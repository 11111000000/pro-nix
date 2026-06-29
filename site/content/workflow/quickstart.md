+++
title = "Быстрый старт"
template = "page.html"
weight = 1

[extra]
tldr = "git clone, git submodule update --init, just switch <host>. Четыре хоста: desktop, cf19, huawei, vm. От clone до загрузки свежей машины — около 30 минут."

[[extra.next]]
title = "just-рецепты"
url = "/workflow/just/"

[[extra.next]]
title = "Сабмодули"
url = "/workflow/submodules/"
+++

# Быстрый старт

Свежая машина, от `clone` до `boot`, занимает около 30 минут.
Последовательность ниже предполагает, что Nix уже установлен (см.
[гайд по установке NixOS](https://nixos.org/manual/nixos.org/) или
[установщик Nix package manager](https://nixos.org/download.html)).

## 1. Клонировать репо

```bash
git clone https://github.com/11111000000/pro-nix
cd pro-nix
git submodule update --init --recursive
```

Инициализация сабмодулей занимает 5-10 минут в зависимости от
сети (11 сабмодулей, ~30 MB всего). HTTPS по умолчанию; переключите
на SSH через `just submodules-ssh`, если есть write-доступ.

## 2. Выбрать хост

Четыре хоста:

| Хост | Класс | Когда использовать |
|------|-------|---------------------|
| `desktop` | сервер, control plane | Always-on башня |
| `cf19` | ноутбук, BIOS-эра | Старый ноутбук (Panasonic CF-MX или похожий) |
| `huawei` | ноутбук, современный Intel | Современный Intel-ноутбук |
| `vm` | изолированная тестовая VM | QEMU/KVM-гость для тестов |

Если стартуете с нуля, **`vm` — самый безопасный выбор** — не
требует специфического железа и использует минимальный baseline.

## 3. Войти в devShell

```bash
nix develop
```

Это:

* Подтянет все нужные инструменты (nix, just, direnv, gh, emacs, …).
* Создаст скрипт `.pro-emacs-wrapper/emacs-pro`, оборачивающий
  Emacs с `-L` флагами для каждого overlay-предоставленного пакета.
* Экспортирует `just`-рецепты, которые использует остальная часть
  страницы.

Если используете `direnv`, `.envrc` загрузит ту же shell
автоматически при `cd` в директорию.

## 4. Собрать хост

```bash
just build <host>
# например just build vm
```

Это запускает
`nix build ".#nixosConfigurations.<host>.config.system.build.toplevel"`
с **правильным** URL flake (`git+file://$(pwd)?submodules=1`).
Первая сборка занимает 10-30 минут в зависимости от машины
(скачивается ~5 GB бинарного кэша + собирается всё, что не в
кэше).

## 5. Switch (применить сборку)

```bash
sudo just switch <host>
# например sudo just switch vm
```

`just switch` запускает `scripts/helper-switch.sh`, который:

* Инициализирует сабмодули, если они не инициализированы.
* Запускает `sudo nixos-rebuild switch` с правильным URL flake.
* При успехе: фиксит владение `~/.config/emacs`,
  `~/.local/state/pro-emacs`, `~/.cache/pro-emacs` (потому что
  `nixos-rebuild switch` мог записать их под root).
* Деплоит `bin/*` в `~/bin` и добавляет `~/bin` в PATH в
  `~/.profile`.

## 6. Задеплоить AI-агентские конфиги

```bash
just deploy-agents
```

Это запускает `scripts/deploy-agent-configs.sh` (copy-if-missing
деплой `local-templates/*` в `~/.config/opencode/` и
`~/.pi/agent/`) и `scripts/install-pi-packages.sh`
(идемпотентный `pi install npm:<pkg>` для каждого пакета в
`settings.json`).

Файл `~/.pi/agent/auth.json` **никогда** не пишется деплоем — он
создаётся при первом запуске `pi` и в deny-листе permission-системы.

## 7. Настроить секреты

Добавьте ваши AI-провайдер-ключи в `~/.authinfo`:

```
machine api.aitunnel.ru  login token  <AITUNNEL_KEY>
machine openrouter.ai    login token  <OPENROUTER_KEY>
machine api.openai.com   login openai <OPENAI_KEY>
```

Или, если предпочитаете GPG-шифрование, `~/.authinfo.gpg` в том же
формате.

Скрипт `~/.local/share/pro-nix/load-agent-env.sh` (деплоится через
`pro-agent-configs.nix`) читает authinfo-файл и экспортирует
`AITUNNEL_KEY`, `OPENROUTER_KEY`, `OPENAI_API_KEY` и т.д. Строка в
`~/.profile` добавляется автоматически активацией.

## 8. Настроить SSH-ключи

Для SSH-доступа с других хостов в кластере (или с внешней машины
на этот):

```bash
# Сгенерировать ключ (один раз, на машине, с которой будете подключаться)
ssh-keygen -t ed25519 -C "<user>@$(hostname)" -f ~/.ssh/id_ed25519

# Скопировать на целевой хост
ssh-copy-id -i ~/.ssh/id_ed25519.pub <user>@desktop.local

# Проверить
ssh -o ConnectTimeout=3 desktop 'uname -a'
```

`~/.ssh/authorized_keys` на каждом хосте стартует **пустым** by
design (`users.users.<name>.openssh.authorizedKeys.keys = []` в
`pro-users.nix`) — ключи должны быть добавлены явно, либо через
`local.nix`, либо через `ssh-copy-id`.

## 9. Проверить сетевой слой

```bash
# mDNS-резолв
getent hosts desktop.local      # должен вернуть LAN-IP

# NFS autofs (на клиентском хосте)
systemctl status mnt-desktop.automount
ls /mnt/desktop                  # ≤ 3 с, даже если desktop выключен

# SSH-список кандидатов
ssh -G desktop | head -30       # показывает кандидатов из ssh_config.d/pro.conf
```

## 10. Smoke-test

```bash
# NixOS-уровень
nix flake check

# Emacs-уровень
M-x pro/reload-config            # внутри Emacs
M-x pro-keys-report-pending      # должно напечатать "no pending bindings"

# Network-контракт
just network-contract

# Headless Emacs-тесты
just headless-tests
```

Если все четыре пройдут — у вас рабочая установка pro-nix.

## Типичные проблемы при первой установке

| Симптом | Фикс |
|---------|-------|
| `nix flake check` жалуется на отсутствующие сабмодули | `git submodule update --init --recursive` |
| `just switch` падает с `error: path '/nix/store/...emcp' does not exist` | Сабмодули не инициализированы. См. выше. |
| `ssh desktop` висит | mDNS / Avahi не работает. `sudo systemctl restart avahi-daemon` |
| `pi` жалуется на отсутствие `mcp.json` | `just deploy-agents` |
| `pi install` падает с "package not found" | `just install-pi-packages` перезапускает с деплоированным `settings.json` |
| `M-x pro/reload-config` падает с "module not owned by current user" | `sudo chown -R $USER ~/.config/emacs` (helper-switch.sh делает это) |

## Что делать после первой установки

* См. [Per-host чек-лист](workflow/per-host.md) для шагов,
  специфичных для каждого хоста.
* См. [Troubleshooting](workflow/troubleshoot.md) для таблицы
  симптом → причина → фикс.
* Прочтите [Соглашения](conventions/_index.md) перед любым
  изменением.
