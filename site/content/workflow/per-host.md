+++
title = "Per-host чек-лист"
template = "page.html"
weight = 8

[extra]
tldr = "После just switch у каждого хоста свой маленький список post-install шагов. desktop нуждается в бэкапе noise-ключа + создании user; cf19 — в i8042-sanity + WiFi-recovery; huawei — в SOF-аудио; vm — в sudo-sanity."

[[extra.next]]
title = "Troubleshooting"
url = "/workflow/troubleshoot/"

[[extra.next]]
title = "Быстрый старт"
url = "/workflow/quickstart/"
+++

# Per-host чек-лист

После `sudo just switch <host>`, у каждого хоста свой маленький
список post-install шагов. Списки ниже предполагают, что хост
собран с дефолтным `local.nix` (без секретов, без override'ов).

## desktop

```bash
# 1. SSH-ключи
ssh-copy-id -i ~/.ssh/id_ed25519.pub <user>@desktop.local

# 2. Avahi (mDNS для LAN-SSH-обнаружения)
systemctl status avahi-daemon
avahi-browse -rt _ssh._tcp | grep desktop
getent hosts desktop.local
getent hosts cf19.local        # если cf19 онлайн

# 3. NFS-export setup
install -d -m 2775 -o root -g pro /srv/nfs
exportfs -v | grep /srv/nfs

# 4. Headscale — бэкап noise-ключа ОДИН РАЗ
sudo cp /var/lib/headscale/noise_private.key /etc/headscale/
sudo chmod 0600 /etc/headscale/noise_private.key
# Запинить через local.nix:
#   headscale.settings.noise.private_key = "<base64>"

# 5. Headscale user + preauthkey
sudo headscale users create <user>
sudo headscale preauthkeys create --user <user> --reusable --expiration 24h
# Сохраните preauthkey — вставьте в switch клиентского хоста.

# 6. Headscale слушает 0.0.0.0:8080 (LAN only по умолчанию)
#    Если принимать регистрации из WAN, добавьте в local.nix:
#      networking.firewall.allowedTCPPorts = [ 8080 ];

# 7. Tor (если хотите onion-имя для SSH)
sudo systemctl status tor
#    /var/lib/tor/ssh_hidden_service/hostname — это onion.
#    Зарегистрируйте в pro.hosts.desktop.onion через local.nix.

# 8. zram
systemctl status zram.slice

# 9. LAN-шлюз
sysctl net.ipv4.ip_forward        # должно быть 1
ip route show default
```

## cf19

```bash
# 1. SSH-ключи
ssh-copy-id -i ~/.ssh/id_ed25519.pub <user>@cf19.local

# 2. BIOS-mode sanity
cat /proc/cmdline | tr ' ' '\n' | rg i8042
# Должно включать: i8042.reset, i8042.nomux
# Также: mitigations=off, preempt=full, mem_sleep_default=s2idle

# 3. WiFi-recovery скрипт установлен
command -v ops-wifi-recover
sudo ops-wifi-recover    # если WiFi не возвращается после s2idle

# 4. Avahi
getent hosts desktop.local
getent hosts cf19.local

# 5. NFS autofs
systemctl status mnt-desktop.automount
ls /mnt/desktop                # ≤ 3 с, даже если desktop выключен

# 6. EXWM-сессия
ls /run/systemd/system/display-manager.service
# Должен быть (gdm). Login → EXWM.
# Если чёрный экран: Ctrl+Alt+F2, логин в tty2, посмотрите
# ~/.local/share/xorg/Xorg.0.log

# 7. Emacs soft-reload
# Внутри Emacs: M-x pro/reload-config
# Должен перезагрузить все 64 модуля без ошибок.

# 8. Tor onion (если allowTorHiddenService был установлен)
sudo cat /var/lib/tor/ssh_hidden_service/hostname
# Зарегистрируйте в pro.hosts.cf19.onion через local.nix на desktop.

# 9. dbus-regression guard
# Override в hosts/cf19/configuration.nix должен предотвратить
# падение `nixos-rebuild switch` в TTY. Если это всё же случается,
# проверьте:
systemctl show dbus.service | grep -E 'Reload|Trigger'
```

## huawei

```bash
# 1. SSH-ключи
ssh-copy-id -i ~/.ssh/id_ed25519.pub <user>@huawei.local

# 2. SOF-аудио (snd-intel-dspcfg dsp_driver=1)
lsmod | rg snd_intel_dspcfg
lsmod | rg snd_sof
speaker-test -c 2 -t wav        # должен издать звук
alsamixer                       # проверьте, что спикеры не замьючены

# 3. Intel GPU
cat /proc/cmdline | tr ' ' '\n' | rg i915
# Должно включать: i915.enable_psr=0, acpi_backlight=native

# 4. Haskell
ghc --version                    # должен напечатать версию GHC
cabal --version
stack --version
which haskell-language-server-wrapper

# 5. Avahi / NFS — обратите внимание, huawei на другой подсети
getent hosts huawei.local
# getent hosts desktop.local ожидаемо пуст, пока
# headscale не свяжет подсети.
ls /mnt/desktop                  # 3-секундный таймаут (autofs nofail)

# 6. Sway
# Запустите Sway из TTY:
sway
# Если wl_compositor падает 2 с после старта, посмотрите
# ~/.cache/emacs-startup/gdm-exwm.log (EXWM-session-launcher пишет
# туда, даже когда не используется Sway).
```

## vm

```bash
# 1. SSH-ключи
ssh-copy-id -i ~/.ssh/id_ed25519.pub <user>@vm.local

# 2. systemctl --failed (минимальный baseline должен быть чистым)
systemctl --failed

# 3. NFS autofs (единственная сетевая зависимость)
systemctl status mnt-desktop.automount
ls /mnt/desktop                  # ≤ 3 с, даже если desktop выключен

# 4. Docker (мост pro-dev)
docker network ls | rg pro-dev
docker run --rm --network pro-dev alpine:3.20 ip addr

# 5. Nix sanity
nix flake check

# 6. Пользовательские пароли (VM стартует с пустым root-паролем)
sudo passwd <user>
# Другие пользователи (za, la, bo) стартуют заблокированными —
# установите их пароли здесь, если нужны.

# 7. Запустите smoke-checks
just headless-tests              # если есть display
just network-contract
```

## Универсальные (любой хост)

```bash
# SSH-ключи (один раз)
ssh-keygen -t ed25519 -C "<user>@$(hostname)" -f ~/.ssh/id_ed25519

# Если этот хост должен быть достижим с других хостов кластера:
ssh-copy-id -i ~/.ssh/id_ed25519.pub <user>@<other-host>.local

# Или через local.nix на ДРУГОМ хосте:
#   users.users.<user>.openssh.authorizedKeys.keys = [
#     "ssh-ed25519 AAAA... <user>@<this-host>"
#   ];

# Установите ваши AI-провайдер-ключи
mkdir -p ~/.authinfo
chmod 0600 ~/.authinfo
$EDITOR ~/.authinfo
# Добавьте строки вроде:
#   machine api.aitunnel.ru  login token  <key>
#   machine openrouter.ai    login token  <key>
#   machine api.openai.com   login openai <key>

# Задеплоить AI-агентские конфиги
just deploy-agents

# Запустить EMCP (MCP-сервер внутри Emacs)
emacsclient -e '(pro-emcp-server-start)'

# Проверить, что агент видит MCP-серверы
pi -p 'mcp({})'
# Должно показать: 2/2 сервера (emcp, chrome-devtools)

# Инициализировать сабмодули (если ещё не сделано)
git submodule update --init --recursive

# Ре-верифицировать Nix eval
nix eval --json .#nixosConfigurations.$(hostname).config.environment.systemPackages \
  | jq -r '.[]' | rg -c .
# Должно быть большое число (~сотни пакетов).
```

## Per-host таблица ролей

| Хост | Роли | NFS | Headscale | LAN-gw |
|------|-------|-----|-----------|--------|
| `desktop` | server, headscale, lan-gw, nfs, tor | server | yes | yes |
| `cf19` | laptop, tor | client | no | no |
| `huawei` | laptop, tor | disabled (другая подсеть) | no | no |
| `vm` | vm, lab | client | (опция не существует) | no |
