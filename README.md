# Pro-Nix Environment

Домашняя NixOS конфигурация с Emacs разработкой.

## Быстрый старт

### 1. Создайте новую среду

```bash
# Клонировать репозиторий
git clone <repo-url> pro-nix
cd pro-nix

# Инициализировать субмодули (по умолчанию HTTPS для всех)
git submodule update --init --recursive
```

### 2. Базовые проверки

```bash
# Синтаксис конфигурации
nix-instantiate --parse configuration.nix

# Проверить flake
nix flake check
```

### 3. Разработка (HTTPS)

```bash
# Перезагрузить NixOS с актуальными субмодулями
sudo nixos-rebuild switch --flake "git+file://$(pwd)?submodules=1#<hostname>"

# Обновить Emacs после изменений в модулях
C-x M-c  # в Emacs
# или
M-x pro/reload-config
```

### 4. Производственное развёртывание (SSH для пуша)

```bash
# Сменить все субмодули на SSH (если у вас есть права на пуш)
just submodules-ssh

# Перезагрузить систему
sudo nixos-rebuild switch --flake "git+file://$(pwd)?submodules=1#<hostname>"
```

## Управление субмодулями

### Субмодули по умолчанию (HTTPS)

- Все субмодули используют HTTPS по умолчанию для работы без SSH-ключей
- Субмодуль `agent-shell-hud` был изменён с SSH на HTTPS в `.gitmodules`
- HTTPS обеспечивает чтение (клонирование), но без возможности пуша

### Если вам нужен SSH для пуша

```bash
# Изменить конкретный субмодуль на SSH локально
git config submodule.submodules/agent-shell-hud.url git@github.com:11111000000/agent-shell-hud.git
git submodule sync
git submodule update --remote --merge
```

### Сменить все на SSH

```bash
# Преобразовать все HTTPS-субмодули в SSH (только если у вас есть SSH-ключ)
./scripts/submodules-ssh.sh
```

### Вернуться обратно к HTTPS

```bash
# Восстановить исходную конфигурацию .gitmodules
cp .gitmodules.backup.<timestamp> .gitmodules

# Обновиться до HTTPS
git submodule sync && git submodule update --remote --merge
```

## Управление через `just`

| Команда | Что делает |
|---------|--------------|
| `just switch <HOST>` | NixOS-rebuild switch (обновляет субмодули автоматически) |
| `just submodules-ssh` | Преобразовать все субмодули в SSH |
| `just build <HOST>` | Nixos-rebuild build |
| `just test <HOST>` | Nixos-rebuild test |
| `just flake-check` | Nix flake check с субмодулями |
| `just headless-tests` | Запустить Emacs headless-тесты |
| `just headless-report` | Отчёт по headless-тестам |
| `just network-contract` | Проверить сетевой контракт (pro.hosts / ssh_config) |

## Настройка после `just switch`

`nixos-rebuild switch` поднимает ядро, сеть, сервисы и пакеты, но **не** делает
несколько вещей, которые требуют ручного шага или локального секрета. Этот
раздел — чек-лист для каждой машины после первой активации.

### 0. Базовый чек-лист (все хосты)

```bash
# 0.1 Проверить, что submodules подтянулись (нужно для Emacs-рецептов)
git submodule update --init --recursive

# 0.2 Проверить, что flake eval проходит и packages попали в сборку
nix eval --json .#nixosConfigurations.$(hostname).config.environment.systemPackages \
  | jq -r '.[]' | rg -c .

# 0.3 Перезагрузить Emacs (важно: NixOS-rebuild не перезапускает Emacs-юзердаемон)
C-x M-c            # в Emacs; то же что M-x pro/reload-config
# или жёсткий reload, если что-то сломалось:
C-u M-x pro/reload-config
```

### 1. SSH-ключи (на каждом клиенте и сервере)

В `modules/pro-users.nix` все 4 пользователя (`az, za, la, bo`) объявлены с
`openssh.authorizedKeys.keys = []` — это **намеренно пусто**, чтобы ключи
не попали в публичный репозиторий. Заливать нужно либо через `local.nix`,
либо руками.

**Сгенерировать ключ (один раз, на той машине, с которой будете заходить):**

```bash
ssh-keygen -t ed25519 -C "az@$(hostname)" -f ~/.ssh/id_ed25519
# по умолчанию `pro-ssh-clients` ожидает именно этот путь; если выберете
# другое имя — см. ниже «нестандартный путь».
```

**Скопировать публичный ключ на все хосты реестра `pro.hosts`:**

```bash
# Быстрый путь: после первого switch, если avahi уже работает,
# scp сможет зайти по <host>.local (см. раздел «mDNS»).
ssh-copy-id -i ~/.ssh/id_ed25519.pub az@desktop.local
ssh-copy-id -i ~/.ssh/id_ed25519.pub az@cf19.local
ssh-copy-id -i ~/.ssh/id_ed25519.pub az@huawei.local
ssh-copy-id -i ~/.ssh/id_ed25519.pub az@vm.local
```

**Альтернатива: `local.nix` (на каждом хосте, до первого `just switch`)**

`local.nix` живёт в корне репозитория, **не коммитится** (см. `.gitignore`).
В нём можно переопределить `pro.hosts.<name>.keys` или
`users.users.<name>.openssh.authorizedKeys.keys`. Шаблон — `local.nix.example`:

```nix
{ ... }:
{
  users.users.az.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAA... az@laptop1"
    "ssh-ed25519 AAAA... az@laptop2"
  ];
  users.users.za.openssh.authorizedKeys.keys = [ "ssh-ed25519 ..." ];
  # ... la, bo — по тому же принципу
}
```

После правки `local.nix`: `just switch` на этом хосте.

**Нестандартный путь к ключу** (`~/.ssh/id_work`, `~/.ssh/id_ed25519_custom`):
добавьте в `local.nix`:
```nix
pro.sshClient.identityFile = "/home/az/.ssh/id_work";
```
Это применится на этом хосте и попадёт в `/etc/ssh/ssh_config.d/pro.conf`.

**Проверить, что всё работает:**
```bash
# с любой машины в LAN:
ssh -G desktop | grep -E 'identityfile|hostname'   # что генерируется
ssh -v desktop 'echo ok' 2>&1 | grep -E 'Authentication|publickey'
```

### 2. mDNS / Avahi (`.local` имена)

`modules/pro-network.nix` включает Avahi + nss-mdns, чтобы `host.local`
резолвился в LAN. На каждом клиенте нужно **убедиться**, что работает:

```bash
# На desktop (сервере):
systemctl status avahi-daemon
avahi-browse -rt _ssh._tcp | grep -i ssh   # должен увидеть соседей

# На клиенте:
getent hosts desktop.local   # должен вернуть LAN-IP
ssh desktop.local 'echo ok'  # должно подключиться
avahi-browse -rt _ssh._tcp
```

Если `getent hosts desktop.local` возвращает пусто — nss-mdns не подхвачен.
Чинится:
```bash
sudo nixos-rebuild switch   # пересобрать с nss-mdns в profile
# или вручную:
grep mdns /etc/nsswitch.conf  # должно быть `hosts: ... mdns4_minimal [NOTFOUND=return] mdns4 ...`
```

**Anti-паттерн**: включать MulticastDNS=yes в `services.resolved`
параллельно с Avahi — даёт конфликт по RFC 6762 § 15 (avahi видит
"another mDNS stack" и уходит в holding mode). Поэтому `desktop` оставляет
`resolved.llmnr = "false"` (см. `hosts/desktop/configuration.nix`).

### 3. NFS-шара `/mnt/desktop`

После `just switch` с `pro.nfs.client.enable = true` (по умолчанию на всех
клиентах) **autofs-unit `mnt-desktop.automount` стартует автоматически**.
При первом обращении к `/mnt/desktop` autofs поднимет NFS-mount.

```bash
# Проверить, что unit жив:
systemctl status mnt-desktop.automount
systemctl status mnt-desktop.mount   # появится после первого ls

# Проверить таймауты (cf19/huawei/vm):
grep -E "timeo|retrans|mount-timeout" /etc/fstab
#   timeo=10,retrans=1,x-systemd.mount-timeout=3,nofail  ← эти значения
```

**Когда шара недоступна** (desktop выключен, LAN без связи):

```bash
ls /mnt/desktop
# ls: cannot open directory '/mnt/desktop': No such device   # не ошибка autofs
#                                                  ↑ 3 секунды
# Раньше было ~25 секунд (старые таймауты). Сейчас — 3 с, см. modules/pro-nfs.nix.
```

Если хочется **принудительно не зависеть** от autofs вовсе
(например, на ноутбуке в дороге), отключите на этом хосте:

```nix
# hosts/cf19/configuration.nix (или local.nix override):
fileSystems."/mnt/desktop".options = lib.mkForce [ "noauto" ];
# или совсем убрать точку монтирования.
```

### 4. Headscale (только `desktop`)

`desktop` — единственный хост с `headscale.enable = true` (см.
`hosts/desktop/configuration.nix`). По умолчанию слушает `0.0.0.0:8080` с
baseDomain `pro-nix.ts.net`.

**Что нужно сделать руками:**

1. **Задать уникальный `private_key` и `noise.private_key`** (Headscale их
   генерирует сам при первом запуске, но при `nixos-rebuild switch` они
   пере-генерируются → все зарегистрированные клиенты теряют сессии).
   ```bash
   sudo cp /var/lib/headscale/noise_private.key /etc/headscale/
   sudo chmod 0600 /etc/headscale/noise_private.key
   # и закрепить в local.nix:
   # headscale.settings.noise.private_key = "<base64>";
   ```

2. **DERP-сервер** (опционально, но без него клиенты ходят через публичный
   DERP, что медленно). `local.nix` на desktop:
   ```nix
   headscale.derpUrls = [
     "https://controlplane.tailscale.com/derpmap/default"
   ];
   # или свой:
   # headscale.derpUrls = [ "https://derp.example.com" ];
   ```

3. **Firewall**: Headscale слушает 8080/tcp. Если хотите принимать регистрации
   из WAN, добавьте в `local.nix`:
   ```nix
   networking.firewall.allowedTCPPorts = [ 8080 ];
   ```
   По умолчанию закрыто (только LAN).

4. **Регистрация клиента**:
   ```bash
   # на desktop:
   sudo headscale users create az
   sudo headscale preauthkeys create --user az --reusable --expiration 24h
   # ↑ preauthkey

   # на клиенте (cf19 / huawei / vm):
   sudo tailscale up --login-server http://desktop.local:8080 --authkey=<KEY>
   ```

### 5. Пользовательские пароли

`users.users.<name>` создаются без пароля (`hashedPassword = null` →
учётка заблокирована до явной разблокировки). Это безопасно для SSH-only
хостов, но **нельзя зайти через TTY/getty** без пароля.

Чтобы разблокировать:
```bash
# На целевом хосте:
sudo passwd az
sudo passwd za
# ...
```

Если хотите пароли в репозитории (не рекомендуется):
```nix
# local.nix:
users.users.az.hashedPassword = "!";
# ↑ = "password never set" (используйте passwd команде выше)
```

### 6. Sudo / nopassword

`modules/pro-users.nix` разрешает `az, za, la, bo` запускать `ALL` через
`sudo` **без пароля**. Это удобно для `just switch`, `nixos-rebuild` и
`apt-equivalent`, но **повышает риск при компрометации учётки**. Если
хотите пароль для sudo — отключите per-host:

```nix
# hosts/cf19/configuration.nix (или local.nix):
security.sudo.wheelNeedsPassword = lib.mkForce true;
```

### 7. Per-host чек-листы

#### 7.1. `desktop` (server / NFS-server / headscale / lan-gw)

- [ ] SSH-ключи залиты (см. §1).
- [ ] Avahi публикует SSH: `avahi-browse -rt _ssh._tcp | grep desktop`.
- [ ] NFS-export создан: `exportfs -v | grep /srv/nfs` (только desktop).
- [ ] `/srv/nfs` существует и writable для группы `pro`:
  ```bash
  sudo install -d -m 2775 -o root -g pro /srv/nfs
  ```
- [ ] Headscale запущен: `systemctl status headscale`.
- [ ] Headscale ключи защищены от пере-генерации (см. §4.1).
- [ ] Tor: если хотите onion-имя для аварийного доступа:
  ```bash
  sudo apt-get install -y tor   # не делать; tor в Nix-профиле
  # см. modules/pro-privacy.nix
  ```
- [ ] zram активен: `systemctl status zram.slice`.
- [ ] LAN-gw (если это ваш uplink): `pro.network.allowSubnetRouter = true`
  уже выставлен в `hosts/desktop/configuration.nix`. Проверьте
  `sysctl net.ipv4.ip_forward` → `1`.

#### 7.2. `cf19` (Panasonic Let's Note CF-MX, ноутбук)

- [ ] GRUB-загрузчик: `/boot` смонтирован, EFI неактивен (BIOS-режим).
  Убедитесь, что после `just switch` нет ошибок `cannot touch EFI vars`.
- [ ] WiFi-recover скрипт на месте:
  ```bash
  command -v ops-wifi-recover
  sudo ops-wifi-recover    # если WiFi не поднимается после s2idle
  ```
- [ ] `i8042.reset i8042.nomux mitigations=off preempt=full` применены:
  ```bash
  cat /proc/cmdline | tr ' ' '\n' | rg i8042
  ```
- [ ] Avahi: `getent hosts desktop.local` возвращает IP.
- [ ] NFS-mount `/mnt/desktop` доступен (или корректно отказывает за 3 с).
- [ ] EXWM сессия: `ls /run/systemd/system/display-manager.service` →
  GDM. Логин → EXWM. Если чёрный экран — `Ctrl+Alt+F2`, логин в tty,
  `~/.local/share/xorg/Xorg.0.log` для диагностики.
- [ ] `pro/reload-config` подхватывает изменения в `emacs/base/modules/`.

#### 7.3. `huawei` (ноутбук, Intel GPU)

- [ ] systemD-boot активен: `bootctl status` (не GRUB).
- [ ] GPU: `i915.enable_psr=0` применён:
  ```bash
  cat /proc/cmdline | tr ' ' '\n' | rg i915
  ```
- [ ] Звук: `snd-intel-dspcfg dsp_driver=1` загружен (см. `boot.extraModprobeConfig`):
  ```bash
  lsmod | rg snd_intel_dspcfg
  ```
- [ ] Haskell-окружение доступно: `ghc --version`, `cabal --version`,
  `stack --version` (все три в `modules/pro-haskell.nix`).
- [ ] Avahi / NFS — те же проверки, что и для cf19.

#### 7.4. `vm` (server-only, без GUI)

- [ ] Собран через `mkVmHost` в `flake.nix` (см. комментарий в
  `hosts/vm/configuration.nix`). Базовый NixOS-eval без display manager.
- [ ] Sudo без пароля для az (потому что `security.sudo.wheelNeedsPassword = lib.mkForce false;`).
- [ ] root-пароль пуст (`users.users.root.password = "";`) — годится
  **только** для изолированной VM. В проде замените.
- [ ] `pro.nfs.client.enable = true` — автоподключение `/mnt/desktop`.
- [ ] Нет Xorg / display manager: `systemctl status gdm` → `inactive`.

### 8. Smoke-tests после первой настройки

```bash
# 8.1 Сеть
ssh -G desktop | head                        # что генерирует ssh_config
ssh -o ConnectTimeout=3 desktop 'uname -a'    # подключение через mDNS
getent hosts desktop.local                   # mDNS-резолв
mount | rg '/mnt/desktop'                    # autofs-точка

# 8.2 NFS
time ls /mnt/desktop                         # ≤ 3 с, даже если desktop выключен

# 8.3 Emacs
emacsclient -e '(emacs-version)'             # Emacs работает
M-x pro/reload-config                        # модули подтягиваются
M-x pro-keys-report-pending                  # pending-биндинги

# 8.4 Контракты
just network-contract                        # pro.hosts / ssh_config / firewall
just headless-tests                          # Emacs-тесты
nix flake check                              # общая проверка
```

### 9. Если что-то пошло не так

| Симптом | Где смотреть |
|---------|---------------|
| `Permission denied (publickey)` на `ssh desktop` | §1 — ключи не залиты. Проверить `~/.ssh/authorized_keys` на сервере и `~/.ssh/id_ed25519` на клиенте. |
| `getent hosts desktop.local` пусто | Avahi не подхвачен. `sudo systemctl restart avahi-daemon`. Если не помогло — проверить `nsswitch.conf`. |
| `ls /mnt/desktop` висит > 3 с | `grep /mnt/desktop /etc/fstab` → должны быть `timeo=10,retrans=1,x-systemd.mount-timeout=3`. Если нет — `just switch` не подхватил `modules/pro-nfs.nix`. |
| Emacs жалуется на `Cannot open load file "some-pkg"` | `git submodule update --init --recursive` — рецепт не нашёл исходник submodule. |
| `headscale: noise key regenerated, all sessions lost` | §4.1 — скопировать ключи из `/var/lib/headscale/` в `local.nix`. |
| `nixos-rebuild switch` падает на `mount` шаге | Загрузка ждёт NFS. `nofail` уже в опциях (`modules/pro-nfs.nix`). Если не помогло — добавить `x-systemd.mount-timeout=1`. |

## Структура репозитория

```
configuration.nix          # Корневой NixOS-конфиг
dotfiles/                  # Включения для Home Manager (пользовательские настройки)
flake.nix                  # Flake: hosts, nixpkgs pin, checks
justfile                   # Just команды для работы с системой
local.nix                  # Секреты (НЕ КОММИТИТЬ)
modules/                   # NixOS модули (процессорные, system-package-sets, nix-*, ...)
hosts/<name>/              # Конфигурации хостов
emacs/base/                # Emacs Lisp модули (pro-*.el)
.gitmodules                # Определения субмодулей
```

## Советы и решения проблем

### Submodule не инициализирован

Если при `just switch` появляется ошибка типа:
```
fatal: '/home/az/pro-nix/submodules/acapella' does not appear to be a git repository
```

Исправьте:
```bash
git submodule update --init --recursive
just switch
```

### У вас есть SSH-ключ, но клонирование не работает

Если ваша `.gitmodules` содержит SSH URL, клонирование будет работать только
если у вас есть SSH-ключ для репозитория.

Решения:
1. **Если у вас есть SSH-ключ**: Смените все на SSH:
   ```bash
   ./scripts/submodules-ssh.sh
   ```

2. **Если у вас нет SSH-ключа**: Используйте HTTPS (по умолчанию, как реализовано)

### Изменения в Emacs не применяются после `just switch`

```bash
# Быстрый перезапуск Emacs
C-x M-c   # в Emacs
# или
M-x pro/reload-config

# Полный перезапуск (если что-то сломалось)
C-u M-x pro/reload-config
```

### Перезапуск системы

Если вам нужно перезагрузить:

```bash
# Безопасный перезапуск (рекомендуется)
sudo nixos-rebuild boot --flake "git+file://$(pwd)?submodules=1#<hostname>"
sudo reboot

# Быстрый перезапуск (рискует race condition)
sudo nixos-rebuild switch --flake "git+file://$(pwd)?submodules=1#<hostname>"
```

## AGENTS.md

Подробные правила работы с репозиторием, Submodules и Emacs приведены в
`AGENTS.md`. Используйте это в качестве руководства для:

- Редактирования и удаления мёртвого кода
- Управления Submodules
- Конвенций фиксации коммитов
- Проверки изменений
- Emacs разработки

## Связь

Для вопросов или помощи, свяжитесь с создателем.
