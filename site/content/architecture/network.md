+++
title = "Сетевые слои"
template = "page.html"
weight = 6

[extra]
tldr = "Три независимых слоя: LAN mDNS (pro-network + pro-peer), mesh (headscale), SSH-нейминг (pro-ssh-clients). SSH имеет сгенерированный pro.conf с кандидатами в порядке с per-candidate ConnectTimeout."

[[extra.next]]
title = "Быстрый старт"
url = "/workflow/quickstart/"

[[extra.next]]
title = "Приватность и Tor"
url = "/stack/privacy/"
+++

# Сетевые слои

В проекте **три** сетевых слоя, каждый независимый, каждый с
ясной зоной ответственности. Они композируются, не завися друг от
друга. Слой SSH-нейминга — единственный с настоящим фолбэком;
остальные — «best effort» в своём scope.

| Слой | Модуль | Транспорт | Scope |
|------|--------|-----------|-------|
| **LAN mDNS** | `pro-network.nix` (Avahi + nss-mdns) + `pro-peer.nix` (публикует `_ssh._tcp`) | UDP 5353 multicast | Один L2-сегмент |
| **Mesh** | `headscale.nix` (control plane) + будущий `pro-tailnet.nix` (клиенты) | WireGuard | Где есть интернет |
| **SSH-нейминг** | `pro-ssh-clients.nix` (генерит `ssh_config.d/pro.conf`) | SSH поверх того кандидата, что ответит | Всегда (что ответит первым) |

## Слой 1: LAN mDNS

`modules/pro-network.nix` включает `services.avahi` с
`nssmdns4` и `nssmdns6`, так что `getent hosts <name>.local`
резолвится в LAN-IP через glibc NSS-плагин. `nss-mdns` добавлен в
`environment.systemPackages`.

### Конфликт mDNS / resolved

`systemd-resolved` и `avahi-daemon` **не должны** одновременно
отвечать на mDNS-запросы на одном хосте. RFC 6762 § 15 описывает
получающееся предупреждение «another mDNS stack», после которого
Avahi уходит в holding-режим и перестаёт публиковать DNS-SD-записи
(SSH, SMB, NFS). Симптом — `avahi-browse -rt _smb._tcp` пусто.

Фикс — заставить `systemd-resolved` не заявлять mDNS:

```nix
services.resolved.extraConfig = lib.mkIf config.services.resolved.enable (lib.mkAfter ''
  MulticastDNS=no
  LLMNR=no
'');
```

`conf/resolved-extra.conf` имеет то же содержимое как
деплоируемый конфиг. Строка `MulticastDNS=no` — правильная форма;
опция `services.resolved.llmnr` — это enum, но `extraConfig` идёт
напрямую в `resolved.conf` и принимает строковую форму.

### Avahi публикует SSH

`pro-peer.nix` пишет `/etc/avahi/services/ssh.service`:

```xml
<?xml version="1.0" standalone='no'?>
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
  <name replace-wildcards="yes">%h</name>
  <service>
    <type>_ssh._tcp</type>
    <port>22</port>
  </service>
</service-group>
```

macOS, iOS и Android (с Bonjour) могут обнаружить хост по LAN и
подключиться к SSH.

### Firewall

`pro-peer.nix` открывает UDP 5353 (mDNS) и добавляет
iptables/ip6tables-правила для multicast-групп `224.0.0.251` (IPv4)
и `ff02::fb` (IPv6) — стандартные mDNS-группы. Правила
`lib.mkDefault`, так что хост может их переопределить через
`networking.firewall.allowedUDPPorts = []`.

`pro-network.nix` открывает `5353/udp` на том же уровне с той же
семантикой override. Два модуля согласованы by design.

### Роль LAN-gateway

Хосты с ролью `lan-gw` в `pro.hosts` получают
`pro.network.allowSubnetRouter = true` (по умолчанию, вычисляется
из роли). Это устанавливает:

* `net.ipv4.ip_forward = 1`
* `net.ipv6.conf.all.forwarding = 1`
* `networking.firewall.trustedInterfaces = [ "tailscale0" ]`
* `iptables` MASQUERADE на default route (добавлено с `lib.mkBefore`,
  чтобы не перезаписывалось host-local extraCommands).

Только `desktop` имеет эту роль. Это шлюз для tailnet-клиентов,
которые хотят выходить в интернет через стабильный uplink.

## Слой 2: Mesh (headscale)

`modules/headscale.nix` — самохостящийся control plane для
Tailscale-совместимого WireGuard-mesh. Опции:

```nix
options.headscale = {
  enable        = lib.mkEnableOption "...";
  listenAddress = lib.mkOption { default = "0.0.0.0:8080"; };
  baseDomain    = lib.mkOption { default = "pro-nix.ts.net"; };
  nameservers   = lib.mkOption { default = [ "1.1.1.1" "8.8.8.8" ]; };
  derpUrls      = lib.mkOption { default = []; };
};
```

Base domain — `pro-nix.ts.net` (это magic-suffix, который
MagicDNS использует для коротких имён — `desktop` резолвится в
`desktop.pro-nix.ts.net`).

### Инвариант «один хост»

`headscale.enable = true` — default (в глобальном `configuration.nix`).
На каждом ноутбуке / VM host-овский `configuration.nix` делает
`lib.mkForce false`:

```nix
# hosts/cf19/configuration.nix
headscale.enable = lib.mkForce false;
# hosts/huawei/configuration.nix
headscale.enable = lib.mkForce false;
# hosts/vm/configuration.nix
# (нет headscale.* опции в этом eval)
```

Только `desktop` запускает control plane. Забыть `mkForce` на
ноутбуке тихо стартует конкурирующий control plane.

### Как зарегистрировать клиента

```bash
# На desktop
sudo headscale users create az
sudo headscale preauthkeys create --user az --reusable --expiration 24h
# скопировать preauthkey

# На клиенте (cf19, huawei, …)
sudo tailscale up --login-server http://desktop.local:8080 --authkey=<KEY>
```

После регистрации имя хоста достижимо как
`<host>.pro-nix.ts.net` (MagicDNS) и как `<host>` (короткое имя).

### DERP

`derpUrls = []` по умолчанию. Для приватного DERP — установите
`derpUrls = [ "https://my-derp.example.com" ]`. Без DERP клиенты
откатываются на публичный Tailscale DERP map — это медленно, но
работает.

### Подводный камень `noise_private.key`

Headscale генерирует `noise_private_key` на первой активации.
Флоу `nixos-rebuild switch` пере-запускает активацию, что может
**пере-генерировать** ключ — инвалидируя все существующие
клиентские сессии.

Фикс — бэкапнуть ключ один раз и запинить через `local.nix`:

```bash
sudo cp /var/lib/headscale/noise_private.key /etc/headscale/
sudo chmod 0600 /etc/headscale/noise_private.key
```

Затем в `local.nix`:

```nix
headscale.settings.noise.private_key = "<base64-from-the-key-file>";
```

## Слой 3: SSH-нейминг

`modules/pro-ssh-clients.nix` генерирует
`/etc/ssh/ssh_config.d/pro.conf` из реестра `pro.hosts`. Один
`Host`-блок на зарегистрированный хост, с фиксированным списком
кандидатов:

```nix
candidates = [
  "${h.tailnet}.${tailnetDomain}"   # desktop.pro-nix.ts.net (MagicDNS)
  h.tailnet                          # desktop (короткое имя)
  "${name}.local"                    # desktop.local (mDNS)
]
++ optional (h.addr != null) h.addr       # статический IP
++ optional (h.onion != null) h.onion;    # onion (через torsocks)
```

Для каждого `Host`-блока:

```ssh-config
Host desktop
    User az
    Port 22
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
    PreferredAuthentications publickey
    StrictHostKeyChecking accept-new
    HashKnownHosts yes
    UpdateHostKeys yes
    ServerAliveInterval 30
    ServerAliveCountMax 3
    ConnectTimeout 5
```

Каждый кандидат — это своё неявное значение `HostName` через
сгенерированный блок. Первый доступный выигрывает. С
`ConnectTimeout 5` мёртвый `.local` не блокирует рабочий
`tailnet-fqdn`.

Если у хоста есть атрибут `onion`, генерируется отдельный
`Host <name>-onion` блок с `ProxyCommand` через `torsocks`:

```ssh-config
Host desktop-onion
    User az
    HostName <onion-address>.onion
    Port 22
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
    PreferredAuthentications publickey
    ProxyCommand torsocks ssh -W %h:%p
    ConnectTimeout 30
```

`Match exec` срабатывает только когда пользователь печатает
`ssh <name>-onion`, сохраняя дефолтный `ssh <name>` быстрым.

### Опции конфигурации

```nix
pro.sshClient = {
  enable         = lib.mkEnableOption "..." // { default = true; };
  identityFile   = lib.mkOption { default = "~/.ssh/id_ed25519"; };
  connectTimeout = lib.mkOption { default = 5; };  # seconds
};
```

`local.nix` может переопределить:

```nix
pro.sshClient.identityFile = "/home/<user>/.ssh/id_work";
```

Это влияет на строку `IdentityFile` в каждом сгенерированном
`Host`-блоке.

## Как три слоя композируются

```
пользователь ssh desktop
   |
   v
[ ssh_config.d/pro.conf ]
   |
   v
SSH-клиент пробует кандидатов в порядке
   |
   +-- desktop.pro-nix.ts.net --[MagicDNS]--> headscale --[WireGuard]--> desktop
   |
   +-- desktop                --[tailscale0]--> desktop
   |
   +-- desktop.local          --[Avahi mDNS]--> desktop
   |
   +-- <addr>                 --[static IP]--> desktop
   |
   +-- desktop-onion           --[torsocks / Tor]--> desktop
```

Пользователь печатает `ssh desktop`. SSH-клиент читает
`ssh_config.d/pro.conf` и пробует кандидатов в порядке. Первый
доступный выигрывает. Если все четыре L2/L3-кандидата падают,
кандидат `<name>-onion` — последний фолбэк, но он требует явного
вызова (`ssh desktop-onion`).

## Почему три слоя, не один

Один слой (например, mesh) означал бы:

* Нет достижимости, когда headscale control plane down.
* Нет достижимости, когда headscale доступен, но Tailscale-демон
  не запущен на клиенте.
* Нет достижимости в LAN без интернета.

Три слоя каждый покрывает свой failure mode:

* **LAN mDNS** — работает в кофейне, в самолёте (без интернета), в
  корпоративной сети. Падает через VLAN'ы / подсети.
* **Mesh** — работает где есть интернет, NAT-traversal. Падает,
  если control plane down.
* **Onion** — работает где есть интернет, даже из враждебной сети,
  где IP-адрес хоста фильтруется. Медленно (3-5x latency).
* **Static addr** — последнее средство, требует знания IP
  пользователем.

SSH-список кандидатов ставит самый быстрый, самый надёжный слой
первым (magic DNS, если доступен) и откатывается на более
медленные слои.

## Per-host сетевая роль

| Хост | Роль | `pro.network.allowSubnetRouter` | `headscale.enable` | NFS |
|------|------|-------------------------------|---------------------|-----|
| `desktop` | `server, headscale, lan-gw, nfs, tor` | true (default) | true (default) | server (`/srv/nfs`) |
| `cf19` | `laptop, tor` | false | false (mkForce) | client |
| `huawei` | `laptop, tor` | false | false (mkForce) | **disabled** (другая подсеть) |
| `vm` | `vm, lab` | false | (опция не существует) | client |
