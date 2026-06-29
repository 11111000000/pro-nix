+++
title = "Troubleshooting"
template = "page.html"
weight = 9

[extra]
tldr = "Таблица симптом → где смотреть. Самые частые: SSH Permission denied, getent hosts .local пуст, ls /mnt/desktop > 3 с, headscale потерял noise-ключ, emcp не виден в pi."

[[extra.next]]
title = "Per-host чек-лист"
url = "/workflow/per-host/"

[[extra.next]]
title = "Быстрый старт"
url = "/workflow/quickstart/"
+++

# Troubleshooting

Таблица «симптом → где смотреть → что делать». Сгруппировано по
слоям.

## SSH и сетевой слой

| Симптом | Где смотреть | Что делать |
|---------|-------------|-----------|
| `Permission denied (publickey)` на `ssh desktop` | `~/.ssh/authorized_keys` на сервере; `~/.ssh/id_ed25519` на клиенте | `ssh-copy-id` или добавьте ключ через `local.nix` |
| `getent hosts desktop.local` пусто | `systemctl status avahi-daemon`; проверьте `nss-mdns` в `/etc/nsswitch.conf` | `sudo systemctl restart avahi-daemon` |
| `ssh desktop` висит | mDNS / Avahi не работает; tailnet-FQDN тоже не резолвится | Проверьте, что оба хоста в одной L2-сети; проверьте, что headscale up на desktop |
| `ls /mnt/desktop` висит > 3 с | `grep /mnt/desktop /etc/fstab` | Должно показать `timeo=10,retrans=1,x-systemd.mount-timeout=3,nofail`. Если нет — `just switch` не подхватил `modules/pro-nfs.nix` |
| `nixos-rebuild switch` висит на `mount` | NFS-монит без `nofail` | Добавьте `x-systemd.mount-timeout=1` per-mount |
| `headscale: noise key regenerated, all sessions lost` | `/var/lib/headscale/noise_private.key` | Backup из `/var/lib/headscale/` в `local.nix` через `headscale.settings.noise.private_key` |
| `tailscale up` падает с `failed to authenticate` | preauthkey истёк | `sudo headscale preauthkeys create --user <user> --reusable --expiration 24h` |
| `ssh -G desktop` показывает `connect: connection refused` ко всем кандидатам | Desktop реально down | Проверьте `ping`, `systemctl status`; SSH-кандидаты — это кандидаты, не гарантии |

## Emacs

| Симптом | Где смотреть | Что делать |
|---------|-------------|-----------|
| `Cannot open load file "some-pkg"` в Emacs | Сабмодуль не инициализирован | `git submodule update --init --recursive` |
| `Module not owned by current user` на каждом reload | sudo-активация записала файлы под root | `sudo chown -R $USER ~/.config/emacs` (helper-switch.sh делает это) |
| Reload вроде ничего не делает | mtime-трюк — `load-history` думает, что файл актуален | `M-x pro/reload-module <module>` |
| Frame выживает после reload, но в неправильной позиции | У модуля нет reset-функции на `pro--after-reload-hook` | Добавьте `pro/after-reload` с reset-функцией |
| Функция вызывается дважды после reload | Top-level форма модуля не идемпотентна | Оберните в `pro-compat--add-{hook,to-list,advice}-once` |
| Reload падает с "Cannot open load file" | Модуль удалён, но манифест всё ещё ссылается | Удалите из `pro-emacs-base-default-modules` в `site-init.el` |
| `M-x pro-keys-report-pending` показывает длинный список | Некоторые Nix-предоставленные пакеты не загрузились | `M-x package-install` недостающие, потом `M-x pro-keys-reload` |
| Emacs стартует без шрифта Aporetic Sans | `fonts/aporetic-*.ttf` не в closure | `nix flake check`; пересобрать `nixosConfigurations.<host>` |
| `pro-ui-zoom-in` / `pro-ui-zoom-out` не работают | Биндинги не подгрузились | Проверьте `M-x pro-keys-report-pending` |

## AI-агенты

| Симптом | Где смотреть | Что делать |
|---------|-------------|-----------|
| `pi` не в PATH | `command -v pi` | `nix develop` или `~/.nix-profile/bin` в `~/.profile` |
| `pi` жалуется на отсутствие `mcp.json` | `~/.pi/agent/mcp.json` | `just deploy-agents` |
| `pi install` падает с "package not found" | `settings.json` устарел | `just install-pi-packages` перезапускает с деплоированным `settings.json` |
| `emcp` не виден в `pi -p 'mcp({})'` | EMCP-сервер не запустился | `emacsclient -e '(pro-emcp-server-start)'`, потом `pi -p 'mcp({})'` |
| `emcp_eval` просит подтверждение каждый раз | `emcp-tools-eval-default-policy` = `'ask` | Это by design. `a` — always accept, `r` — always reject |
| AI-провайдер 401 Unauthorized | env-переменные не загружены | Проверьте `~/.authinfo`; `source ~/.config/pro-tor/env` или откройте новую shell |
| `pi` создал `auth.json` под root | sudo-активация | `sudo chown -R $USER ~/.pi/agent/` |
| opencode MCP tools не появляются | `mcpServers` секция в `opencode.json` | `cat ~/.config/opencode/opencode.json`; перезапустите `opencode` |
| `pi` отказывается запускать `sudo` команду | `bash` permission rule `sudo *` = `ask` | Подтвердите интерактивно; `a` для always-allow |

## Nix и сборка

| Симптом | Где смотреть | Что делать |
|---------|-------------|-----------|
| `nix flake check` жалуется на отсутствующие сабмодули | `git submodule status` | `git submodule update --init --recursive` |
| `nix build` падает на `path does not exist` | Неправильный URL flake | Используйте `git+file://$(pwd)?submodules=1` (just-рецепты делают это) |
| `nix build` падает на `unfree` | `nixpkgsConfig.allowUnfree` не установлен | Уже `true` в `flake.nix`; проверьте, не override'нули ли |
| `nix flake check` молча проходит, но `nix build` падает | Lazy-build не выполнился | `nix-instantiate --parse` для каждого затронутого файла; `nix-instantiate` для derivation |
| `nix-instantiate --parse` падает на syntax error | Сломанный .nix-файл | Исправьте syntax; `nixfmt` отформатирует |
| `PRO_NIX_RUN_SLOW_CHECKS=1 nix flake check` падает на VM-тестах | Не запускается QEMU/KVM | Проверьте, что KVM включён; `ls /dev/kvm` |
| `nix store gc` удалил нужный пакет | GC прошёл до rebuild | `nix-store --query --references` чтобы найти; восстановить через build |

## Сборка / switch

| Симптом | Где смотреть | Что делать |
|---------|-------------|-----------|
| `just switch` не инициализирует сабмодули | `git submodule status` | `git submodule update --init --recursive` или `just switch <host> update-submodules` |
| `just switch` оставляет файлы в `~/.config/emacs` под root | `ls -la ~/.config/emacs` | `sudo chown -R $USER ~/.config/emacs ~/.local/state/pro-emacs ~/.cache/pro-emacs` |
| `nixos-rebuild switch` падает на `unfree` | `nixpkgsConfig.allowUnfree` не `true` | Уже `true`; проверьте, не override'нули |
| `switch` падает на `dbus-broker` restart | `cf19`-специфичный баг | dbus override в `hosts/cf19/configuration.nix` уже есть; проверьте `systemctl show dbus.service` |
| `nixos-rebuild switch` падает на `unit tor-ensure-bridges.service` (searxng) | `lib.mkForce false` в `configuration.nix` | Уже отключено; см. `services.searxng.enable = lib.mkForce false` |
| `switch` оставляет `~/bin` пустым | `bin/` директория в репо | `ls bin/`; `helper-switch.sh` деплоит только если `bin/` существует |

## Хост-специфичные

### cf19

| Симптом | Где смотреть | Что делать |
|---------|-------------|-----------|
| Тачпад не работает после resume | i8042 quirks | `cat /proc/cmdline \| rg i8042`; должны быть `i8042.reset i8042.nomux` |
| WiFi не возвращается после s2idle | iwlwifi quirks | `sudo ops-wifi-recover` (escalating: nmcli radio → connection reload → try-restart NetworkManager) |
| `nixos-rebuild switch` роняет в TTY | dbus-broker restart | Уже есть `lib.mkForce false`; проверьте `systemctl show dbus.service` |

### huawei

| Симптом | Где смотреть | Что делать |
|---------|-------------|-----------|
| Звук мёртв | SOF firmware | `lsmod \| rg snd_sof`; `dmesg \| rg sof`; `dsp_driver=1` в `boot.extraModprobeConfig` |
| Экран моргает/тиринг | i915 PSR | `cat /proc/cmdline \| rg i915`; должно быть `i915.enable_psr=0` |
| NFS не монитирует (desktop на другой подсети) | Разные подсети | `getent hosts desktop.local`; пуст — headscale пока не связывает |
| Haskell LSP не подключается | `haskell-language-server-wrapper` не в PATH | `which haskell-language-server-wrapper`; в `modules/pro-haskell.nix` |

### desktop

| Симптом | Где смотреть | Что делать |
|---------|-------------|-----------|
| Headscale не стартует | `journalctl -u headscale` | Проверьте `/var/lib/headscale/`; backup noise-ключа |
| NFS клиенты не монитируют | `exportfs -v` на desktop; `systemctl status mnt-desktop.automount` на клиенте | `/srv/nfs` должен быть `2775 root:pro`; на клиенте autofs должен быть active |
| LAN-gw не роутит | `sysctl net.ipv4.ip_forward` | Должно быть `1`; `pro.network.allowSubnetRouter` = true (на desktop по умолчанию) |
| `audit` отсутствует | `security.audit.enable` | `mkForce false` на desktop by design (symlink-путь в NixOS несовместим с audit) |

### vm

| Симптом | Где смотреть | Что делать |
|---------|-------------|-----------|
| `headscale.enable` падает | Опция не существует в eval | Не пытайтесь её устанавливать; `headscale.*` определена только в `mkHost` |
| `nix build` падает на `nvidia` | Нет NVIDIA | Опустите `nix-cuda-compat.nix`; или `services.xserver.videoDrivers = [ "modesetting" ]` (уже так) |
| `pro-users.nix` пустой юзер | `pro-users.nix` импортируется в `hosts/vm/configuration.nix` | Проверьте `imports` |

## Проверка всего кластера

```bash
# Все хосты строятся?
nix run .#check-all

# Все unit + contract тесты проходят?
./tools/holo-verify.sh unit
./tools/holo-verify.sh nixos-fast

# Все headless Emacs-тесты проходят?
just headless-tests

# Сетевой контракт жив?
just network-contract

# Все workflow OK?
nix flake check
```

Если все 5 пройдут — кластер в порядке.

## Сайт (этот сайт)

| Симптом | Где смотреть | Что делать |
|---------|-------------|-----------|
| `zola serve` не запускается | `which zola` | `nix develop` или `nix shell nixpkgs#zola` |
| Сайт показывает EN, а хочется RU | URL | `/ru/about/` (с `/ru/` префиксом) |
| Страница `/reference/keys/` показывает 0 биндингов | `scripts/site-extract-keys.py` не запускался | `just site-regen` |
| PR-preview не приходит | `actions/site-preview.yml` не настроен | См. `.github/workflows/site-preview.yml`; настраивается вручную для surge.sh |
| gh-pages деплой падает | `actions/site-build.yml` лог | `Settings → Pages → Source: GitHub Actions`; `permissions: pages: write, id-token: write` |

## См. также

* [Per-host чек-лист](workflow/per-host.md) — что делать после
  `just switch` для каждого хоста.
* [Соглашения](conventions/_index.md) — анти-паттерны, которых
  следует избегать.
* [Troubleshooting в `scripts/README.md`](https://github.com/11111000000/pro-nix/blob/main/scripts/README.md)
  — perf-tuning воркфлоу.
