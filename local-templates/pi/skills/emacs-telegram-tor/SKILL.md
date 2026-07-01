---
name: emacs-telegram-tor
description: Telegram clients (TDesktop и telega.el через telega-server) автоматически работают через Tor SOCKS5 когда Tor доступен на 127.0.0.1:9050. Использовать когда нужна анонимизация подключения к Telegram и есть Tor (локальный services.tor или upstream SOCKS5 от Android-tethering через WiFi).
---

# Telegram через Tor в pro-nix

Telegram MTProto ходит на серверы напрямую — mainline tdlib **не поддерживает SOCKS5 proxy** через elisp. Поэтому единственный надёжный путь к анонимизации — системный SOCKS5 (Tor) через `torsocks`, который прозрачно перехватывает TCP-вызовы через LD_PRELOAD.

## 1. Архитектура

```
┌─────────────────────────────────────────────┐
│ Telegram Desktop (Qt app)                    │
│  запущен через tdesktop-tor-launch          │
│  (torsocks telegram-desktop ...)            │
└────────────────────┬────────────────────────┘
                     │ TCP (intercepts)
                     ▼
              ┌─────────────────┐
              │   torsocks      │ ← LD_PRELOAD
              │   (SOCKS5 client)│
              └────────┬────────┘
                       │
                       ▼ SOCKS5 (127.0.0.1:9050)
              ┌─────────────────┐
              │ Tor daemon      │
              │ services.tor    │  ← services.tor.client.enable
              └────────┬────────┘
                       │ (3-hop circuits)
                       ▼
                  Telegram API
```

И для **telega.el** (Emacs-side):

```
┌─────────────────────────────────────────────┐
│ Emacs (telega.el)                           │
│  telega-server-command = "telega-server-tor-launch"
│  → установлено pro-chat.el при (require 'telega)
└────────────────────┬────────────────────────┘
                     │ start-process
                     ▼
┌─────────────────────────────────────────────┐
│ telega-server-tor-launch (wrapper script)   │
│  проверяет Tor SOCKS5 → torsocks если есть │
│  fallback на direct если Tor нет            │
└────────────────────┬────────────────────────┘
                     │ exec
                     ▼
       ┌─────────────┴────────────┐
       ▼ torsocks                ▼ direct
   tdlib          ←  →  →  → Telegram API
   (через Tor)
```

## 2. Проверка текущего состояния

```bash
# 1. Tor daemon работает?
scripts/check-tor-socks.sh                # exit 0 = OK
scripts/check-tor-socks.sh -v            # детали (TCP + SOCKS5 handshake)
scripts/check-tor-socks.sh --level onion # + .onion resolve (медленнее)

# 2. TDesktop wrapper готов?
scripts/tdesktop-tor-launch.sh --check

# 3. telega-server wrapper готов?
scripts/telega-server-tor-launch.sh --check

# 4. Внутри Emacs:
M-x pro/chat-tor-status
```

## 3. Использование

### Telegram Desktop

```bash
# Обычный запуск (с проверкой Tor):
scripts/tdesktop-tor-launch.sh

# На macOS menu: ярлык "Telegram Desktop" уже
# прописан в /etc/xdg/autostart при включённом pro.telegram.useTor.
```

### telega.el в Emacs

**Автоматически**: при `(require 'telega)` → `telega-server-command`
подменяется на `telega-server-tor-launch`. Дефолтное поведение.

**Ручная проверка**: `M-x pro/chat-tor-status` — текущий
`telega-server-command`, наличие wrapper в PATH, состояние Tor SOCKS5.

**Принудительный re-routing**: `M-x pro/chat-tor-reroute-now` —
переустановить `telega-server-command` если Tor только что стал
available.

## 4. Сценарии подключения

### Локальный Tor (services.tor.client.enable = true)

По умолчанию. `services.tor` запускает daemon с SOCKSPort=9050.
TDesktop и telega.el автоматически обнаружат SOCKS5 и завернут трафик.

### Android-tethering (Orbot / TorVPN на телефоне через WiFi)

Orbot VPN даёт SOCKS5 на телефонном IP (например, `192.168.1.42:9050`).
В этом случае `pro.telegram.socksHost = "192.168.1.42"` (per-host в
`local.nix`).

```nix
# hosts/cf19/configuration.nix
pro.telegram.socksHost = "192.168.1.42";  # телефон
```

### Нет Tor (точка доступа без SOCKS5)

Wrapper-скрипт проверяет SOCKS5 при старте. Если недоступен,
`exec telegram-desktop` (direct). Никаких побочных эффектов.

### Принудительно отключить Tor

```elisp
(setq pro/chat-use-tor nil)            ; в Emacs
# или
pro.telegram.disableTor = true;          ; в Nix (для всех хостов)
```

## 5. Опции Nix

`modules/pro-telegram.nix`:

| Опция | Default | Описание |
|-------|---------|----------|
| `pro.telegram.useTor` | `true` | Включить tor-wrapper для TDesktop + telega-server |
| `pro.telegram.disableTor` | `false` | Полностью отключить (force direct) |
| `pro.telegram.socksHost` | `"127.0.0.1"` | SOCKS5 host |
| `pro.telegram.socksPort` | `9050` | SOCKS5 port |
| `pro.telegram.enableTorService` | `true` | Регистрировать systemd unit `pro-telegram-tor.service` (boot-time Tor readiness check) |

## 6. Опции Emacs

`emacs/base/modules/pro-chat.el`:

| Опция | Default | Описание |
|-------|---------|----------|
| `pro/chat-use-tor` | `t` | Перенаправить telega-server через `telega-server-tor-launch` |

## 7. Kлавиши

| Биндинг | Команда | Что делает |
|----------|---------|------------|
| `C-c t s` | `pro/chat-tor-status` | Показать состояние Tor-проксирования |
| `C-c t r` | `pro/chat-tor-reroute-now` | Принудительно re-redirect telega-server-command |

## 8. Что НЕ работает

- **TDesktop через docker** (`telega-use-docker = t`) — torsocks прозрачно
  работает ТОЛЬКО для native бинарей. В Docker контейнере проксирование
  делается на уровне Docker config (`network_mode`, `proxy_url`) — но это
  не внутри scope этого модуля.
- **iOS TDesktop / TDesktop для мобильных** — другой бинарь, не Nix.
- **MTProto прокси** (например `tg-proxy.antipova.net`) — telega.el
  поддерживает через `telega-proxies-add`, но это не наш scope;
  torsocks и SOCKS5 proxy полностью прозрачны для tdlib TCP.

## 9. Диагностика

| Симптом | Проверка |
|---------|----------|
| TDesktop вообще не запускается | `scripts/tdesktop-tor-launch.sh --debug` |
| telega.el ругается "telega-server not found" | `M-x pro/chat-install` или check `exec-path` |
| Tor SOCKS5 не отвечает | `scripts/check-tor-socks.sh -v --level onion` |
| telega.el использует direct вместо Tor | `M-x pro/chat-tor-status` (покажет какой wrapper активен) |
| Хочу всегда direct без Tor | `(setq pro/chat-use-tor nil)` в `~/.config/emacs/custom.el` |
