+++
title = "Приватность и Tor"
template = "page.html"
weight = 5

[extra]
tldr = "Tor + obfs4 + meek + snowflake, onionshare, dnscrypt-proxy, mullvad-vpn, wireguard-tools, yggdrasil mesh. SOCKS5 на 9050, DNS на 9053, control на 9051. pro-tor CLI переключает режим для shell-сессии."

[[extra.next]]
title = "Инструменты разработчика"
url = "/stack/dev/"

[[extra.next]]
title = "Сетевые слои"
url = "/architecture/network/"
+++

# Приватность и Tor

Проект считает **анонимность и censorship-resistance**
first-class-инфраструктурой. Пользователь на гостиничном Wi-Fi,
журналист под давлением режима, разработчик за корпоративным
прокси — все могут направить любую команду через Tor одной
shell-командой.

## Tor-стек

`modules/pro-privacy.nix` активирует:

* `services.tor.enable = true` (задаётся на верхнем уровне в
  `configuration.nix:138-147`; pro-privacy добавляет pluggable
  transports).
* `services.tor.client.enable = true`.
* `services.torsocks.enable = true` — LD_PRELOAD-шим.
* `ClientTransportPlugin`:
  * `obfs4 exec ${pkgs.obfs4}/bin/lyrebird`
  * `meek exec ${pkgs.meek}/bin/meek-client`
  * `snowflake exec ${pkgs.snowflake}/bin/snowflake-client`
* `ControlPort 9051` (cookie auth).
* `DNSPort 9053` с `AutomapHostsOnResolve = true` и
  `AutomapHostsSuffixes = ".onion", ".exit"`.
* `services.i2p.enable = lib.mkDefault false` (выключен по умолчанию).

Мосты управляются `host-policies.nix` (per-host) и
`conf/tor-bridges.conf` (пример). `huawei` имеет snowflake
включённым по умолчанию; `cf19` опционально включает Tor hidden
service для SSH.

## `pro-tor` CLI

`scripts/pro-tor` (~400 строк, bash) — user-facing переключатель
Tor. Два режима:

```bash
pro-tor local on|off|status|detect        # локальный tor.service, 127.0.0.1:9050
pro-tor remote on|off|status|detect       # Orbot на Android AP, сканируемый /24
pro-tor detect [--mode local|remote]      # найти прокси, не включая
pro-tor verify [HOST[:PORT]]              # подтвердить, что это настоящий Tor exit
pro-tor env                               # напечатать export-строки (для eval)
```

### Как детектируется удалённый прокси

Дефолтный набор кандидатов:

1. Default gateway (из `ip -4 route show default`).
2. `<gw%.*.*>.1.1` (если gateway в `*.1.*` паттерне).
3. `192.168.43.1` (Android AP default).
4. `192.168.49.1` (USB-tethering default).
5. С `--scan-subnet`: каждый адрес в /24 gateway'а.

Для каждого кандидата `nc -z -w 1` (или `bash /dev/tcp/...` как
fallback) проверяет TCP 9050, затем
`curl --socks5-hostname $host:9050 https://check.torproject.org/ | grep "Congratulations"`
подтверждает, что это настоящий Tor exit (пропускаемо через
`--no-verify`).

### Что делает `on`

`do_on` пишет `~/.config/pro-tor/env` (mode 0700 dir, 0600 file):

```bash
export ALL_PROXY="socks5h://host:port"
export all_proxy="socks5h://host:port"
export HTTP_PROXY="http://host:port"
export HTTPS_PROXY="http://host:port"
export NO_PROXY="127.0.0.1,localhost,*.local,.local,::1"
export PRO_TOR_MODE="local"   # или "remote"
export PRO_TOR_TARGET="host:port"
export PRO_TOR_ENABLED=1
```

Применить в текущей shell-сессии: `source ~/.config/pro-tor/env` или
`eval "$(pro-tor env)"`.

## `bin/torwrap`

`bin/torwrap` — тонкая обёртка «запусти эту команду через Tor»:

1. Найти `pro-tor` в PATH или в известных Nix-profile путях.
2. `pro-tor detect --no-verify --mode local` (затем `--mode remote`).
3. Если прокси найден, `exec` через `torsocks` → `proxychains4` →
   raw `ALL_PROXY=...`.

Коды выхода:

* `3` — `pro-tor` не найден.
* `4` — Tor-прокси не обнаружен.
* `5` — плохой формат `host:port`.

## Onion-сервисы

`modules/pro-peer.nix` (когда `pro-peer.allowTorHiddenService = true`)
поднимает SSH onion service:

* `services.tor.hiddenService."ssh" = { port = 22; target =
  "127.0.0.1:22"; }`.
* `pro-peer.torBackupRecipient` (GPG key id) используется
  `ops-backup-hiddenservice.sh` для шифрования hidden service dir в
  `/var/lib/pro-peer/hidden-service.gpg`.
* Сгенерированный `ssh_config.d/pro.conf` имеет отдельный
  `Host <name>-onion` блок, использующий torsocks как `ProxyCommand`.

Имя onion регистрируется в `pro.hosts.<name>.onion` и переживает
перезагрузку хоста.

## Yggdrasil и WireGuard

`modules/pro-peer.nix` имеет две opt-in фичи (выключены по
умолчанию):

* `pro-peer.enableYggdrasil` — запускает `yggdrasil` с
  `pro-peer.yggdrasilConfigPath` (по умолчанию `/etc/yggdrasil.conf`).
* `pro-peer.enableWireguardHelper` — устанавливает `wg-quick`-обёртку
  (`pro-peer-wg-quick-wrapper`), которая игнорирует exit-код
  «already up». Использует `pro-peer.wireguardConfigPath` (по
  умолчанию `wg0`).

Это mesh / overlay network fallbacks для случаев, когда ни
LAN-mDNS, ни headscale не дотягиваются до хоста.

## Firewall

`pro-privacy.nix` открывает:

* `9050/tcp` — SOCKS5.
* `9051/tcp` — Control.
* `9052/tcp` — fetch.
* `9053/udp` — DNS.
* `7657/tcp` — I2P console.
* `4444/tcp`, `4445/tcp` — I2P services.
* `9564/udp` — mDNS helper (не используется pro-nix).

По умолчанию они **LAN-only** (RFC1918 sources) через iptables-правила
host-policy в `host-policies.nix`.

## Другие privacy-инструменты в closure

| Пакет | Назначение |
|-------|-----------|
| `dnscrypt-proxy` | Зашифрованный DNS к Cloudflare/Quad9. |
| `onionshare` | Анонимный файлообмен через Tor. |
| `nyx` | Tor relay monitor (TTY). |
| `proxychains` | Альтернатива torsocks для non-LD_PRELOAD сценариев. |
| `mullvad-vpn` | Коммерческий VPN-клиент (без аккаунта). |
| `wireguard-tools` | `wg`, `wg-quick`. |
| `i2p` | I2P router (выключен по умолчанию). |

Они лежат в **privacy** composition-файле
(`system-package-sets-privacy.nix`) и ставятся на `huawei` и `vm` по
умолчанию.

## Чего в стеке **нет**

* `services.tailscale.enable = true` — требует auth-key, ломает
  `nixos-rebuild` без секрета. Роль headscale даёт Tailscale-эквивалентный
  mesh без auth-key.
* `i2p` — включается только по запросу.
* `mullvad-vpn` аккаунт — бинарь установлен, пользователь вводит
  свой аккаунт при первом использовании.
