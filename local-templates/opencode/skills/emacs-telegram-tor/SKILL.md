---
name: emacs-telegram-tor
description: Telegram clients (TDesktop, telega.el) автоматически работают через Tor SOCKS5 когда Tor доступен. Использовать когда нужна анонимизация Telegram и есть Tor (services.tor или upstream через WiFi-tethering на телефон с Orbot/TorVPN).
---

# Telegram через Tor в pro-nix

Quick reference. For full docs see pi skill `emacs-telegram-tor`.

## Verify Tor state

```bash
scripts/check-tor-socks.sh                # exit 0 = Tor OK
```

## Launch

- **TDesktop**: запускается через `tdesktop-tor-launch` (автоматически в PATH после `just switch`). Если Tor не отвечает — fallback на direct.
- **telega.el**: при `(require 'telega)` → `telega-server-command` подменяется на `telega-server-tor-launch`.
- **Status**: `M-x pro/chat-tor-status` (binding `C-c t s`).

## Конфигурация

- Per-host override в `hosts/<host>/configuration.nix`:
  ```nix
  pro.telegram.socksHost = "192.168.1.42";  # телефон через Orbot
  ```
- Per-user override в Emacs:
  ```elisp
  (setq pro/chat-use-tor nil)  # disable для user
  ```
