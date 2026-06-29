+++
title = "Рабочий процесс"
sort_by = "weight"
template = "section.html"

[extra]
tldr = "Ежедневные операции: just-рецепты, политика сабмодулей, деплой агентов, soft-reload, per-host чек-листы, troubleshooting."
+++

Большая часть того, что вы делаете в репо, идёт через `just`. Рецепты
в `justfile:1-164` и сгруппированы в пять кластеров.

## 1. Build / switch

```bash
just switch <host>               # nixos-rebuild switch, post-fix emacs ownership, deploy bin/
just switch-with-agents <host>   # то же + deploy-agent-configs + install-pi-packages
just build <host>                # nixos-rebuild build (без применения)
just test <host>                 # nixos-rebuild test (оффлайн активация)
just flake-check                 # nix flake check с submodules=1
just check-all                   # nix run .#check-all — собирает 3 полных хоста
```

`just switch` запускает `scripts/helper-switch.sh`, который:

* Использует `git+file://$PWD?submodules=1` (path: и . не включают
  сабмодули в captured source)
* Решает политику сабмодулей: `init` если не инициализированы,
  `skip` если есть, `update` только на `--update-submodules` / `sync`
* Пишет `nixos-rebuild switch` в `/tmp/switch-<epoch>.log`
* При успехе: `chown -R $USER` для `~/.config/emacs`,
  `~/.local/state/pro-emacs`, `~/.cache/pro-emacs` (sudo-активация
  может оставить root-owned файлы там)
* Деплоит `bin/*` в `~/bin` и добавляет `~/bin` в `~/.profile` PATH

## 2. Сабмодули

В репо 11 git-сабмодулей, все HTTPS по умолчанию. SSH — opt-in per host.

```bash
git submodule update --init --recursive   # первый раз
just sync-submodules                       # обновить все с remote (sequential, 20s/10s таймауты)
just submodules-ssh                        # конвертировать все HTTPS в SSH (если есть write-доступ)
```

`just switch` **не** обновляет сабмодули с remote по умолчанию;
инициализирует их только если они не инициализированы. Чтобы
форсировать обновление — `just switch <host> update-submodules`.
Чтобы пропустить политику — `PRO_NIX_NO_SUBMODULE_UPDATE=1`.

## 3. Деплой AI-агентов

```bash
just deploy-agents            # скопировать local-templates/{pi,opencode}/* в $HOME
just install-pi-packages      # pi install npm:<pkg> для каждого пакета из settings.json
just switch-with-agents <host>    # цепочка: deploy-agents + install-pi-packages + switch
```

`deploy-agent-configs.sh` — **copy-if-missing** — никогда не перезаписывает
локальные правки пользователя. Чтобы форсировать — `rm` нужный файл
и снова запустить. Скрипт также создаёт
`~/.local/share/pro-nix/load-agent-env.sh` и добавляет маркер-строку
в `~/.profile`, чтобы shell-сессии подхватывали `AITUNNEL_KEY`,
`OPENROUTER_KEY` и т.д. из `~/.authinfo` (или `~/.authinfo.gpg`).

## 4. Emacs soft-reload

Внутри Emacs:

```
C-x M-c            M-x pro/reload-config       быстрый reload (модули в месте)
C-u M-x pro/reload-config                      полный reload (re-evals site-init + все модули)
M-x pro-keys-reload                            перечитать emacs-keys.org
M-x pro-keys-report-pending                    список биндингов, ожидающих пакетов
```

См. [Архитектура → Загрузка Emacs](architecture/emacs-base.md) для
четырёхфазной модели. См. `emacs/base/modules/pro-reload.el:11-22` для
контракта автора модуля.

## 5. Тесты

```bash
just flake-check         # nix flake check
just network-contract    # tests/contract/pro-network-01.sh (5 чеков)
just headless-tests      # запуск Emacs headless ERT
just headless-report     # хвост последнего run-лога
```

Пять слоёв тестов:

1. **`nix flake check`** — синтаксические и type-level проверки.
2. **Slow VM-тесты** — gated by `PRO_NIX_RUN_SLOW_CHECKS=1`;
   поднимают NixOS VM и проверяют, что она загружается / активируется
   чисто.
3. **Contract-тесты** — `tests/contract/*` (sh + el + spec файлы) —
   структурные свойства (pro.hosts имеет 4 записи, headscale
   включён только на desktop, EMCP-порт 38913, …).
4. **Unit-тесты** — `tests/contract/unit/*` (10 коротких скриптов).
5. **GUI smoke** — `tests/gui/gui-smoke.el` под Xvfb.

## 6. Per-host чек-лист

После свежего `just switch` для каждого хоста:

**desktop:**

```bash
# 1. SSH-ключи (один раз, см. README §1)
# 2. Avahi: getent hosts desktop.local
# 3. NFS-export: install -d -m 2775 -o root -g pro /srv/nfs
# 4. headscale: cp /var/lib/headscale/noise_private.key /etc/headscale/
# 5. headscale users create az; preauthkeys create --user az --reusable --expiration 24h
# 6. systemctl status headscale avahi-daemon tor
```

**cf19 / huawei:**

```bash
# 1. SSH-ключи
# 2. getent hosts desktop.local   (должен резолвиться)
# 3. ls /mnt/desktop             (≤ 3 с, даже если desktop выключен)
# 4. M-x pro/reload-config        (подхватывает свежеактивированные модули)
# 5. C-c a  M-x pro-ai-open-entry (gptel-бэкенд доступен)
```

**vm:**

```bash
# 1. SSH-ключи
# 2. systemctl --no-pager --failed
# 3. mount | grep /mnt/desktop
# 4. nix flake check  (sanity)
```

## 7. Troubleshooting

| Симптом | Где смотреть |
|---------|--------------|
| `Permission denied (publickey)` на `ssh desktop` | `~/.ssh/authorized_keys` на сервере; `~/.ssh/id_ed25519` на клиенте |
| `getent hosts desktop.local` пусто | `systemctl restart avahi-daemon`; проверьте `nss-mdns` в `/etc/nsswitch.conf` |
| `ls /mnt/desktop` висит > 3 с | `grep /mnt/desktop /etc/fstab` должен показать `timeo=10,retrans=1,x-systemd.mount-timeout=3,nofail` |
| `Cannot open load file "some-pkg"` в Emacs | `git submodule update --init --recursive` |
| `headscale: noise key regenerated, all sessions lost` | Backup `noise_private.key` из `/var/lib/headscale/` в `local.nix` |
| `nixos-rebuild switch` висит на `mount` | NFS-монит без `nofail`. Добавьте `x-systemd.mount-timeout=1` per-mount |
| `emcp` не виден в pi | `emacsclient -e '(pro-emcp-server-start)'`, потом `pi -p 'mcp({})'` |
| `*.el` reload предупреждает "not owned by current user" | `sudo chown -R $USER ~/.config/emacs` (helper-switch.sh делает это при успехе) |
| surface-lint жалуется на модуль | Добавьте 4 обязательных секции в шапку: Назначение / Цель / Контракт / Proof |

## 8. Правка репозитория

Всегда:

1. Прочтите [Соглашения](conventions/_index.md) — формат коммитов,
   правила mkForce, анти-паттерны, детекторы мёртвого кода.
2. `nix flake check` перед push.
3. `just network-contract`, если трогали сетевой модуль.
4. `just headless-tests`, если трогали Emacs-модуль.
5. Заполните Change-Gate (`Intent:` / `Pressure:` / `Surface:` /
   `Proof:`) в теле PR.
