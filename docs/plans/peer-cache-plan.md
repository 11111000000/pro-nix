<!-- Русский: комментарии и пояснения оформлены в стиле учебника -->
# Peer cache: план внедрения и systemd units

Ниже — практический план и примеры unit-файлов для systemd --user, которые автоматизируют периодическую синхронизацию или запуск после сессии.

1) Минимальная ручная установка

- Установите avahi/ssh на каждой машине.
- Поделитесь публичными ключами в `~/.ssh/authorized_keys` между участниками.
- Создайте `~/.local-peers` с именами `host.local` по одному в строке.
- Используйте `scripts/nix-build-and-share.sh` для сборки и автоматического пуша.

2) systemd --user unit: push-after-login.service

Файл: `~/.config/systemd/user/push-after-login.service`

```ini
[Unit]
Description=Push recent nix store paths to peers after login

[Service]
Type=oneshot
ExecStart=%h/.config/pro-nix/scripts/push-recent-store-to-peers.sh
```

3) systemd --user timer: запустить раз в 6 часов

Файл: `~/.config/systemd/user/push-every-6h.timer`

```ini
[Unit]
Description=Push recent nix store paths to peers every 6 hours

[Timer]
OnBootSec=5m
OnUnitActiveSec=6h

[Install]
WantedBy=default.target
```

Примечание: `push-recent-store-to-peers.sh` — это лёгкий скрипт, который собирает store-пути, созданные в последние N часов (или по журналам) и вызывает `push-nix-to-peers.sh`. Его можно реализовать как удобный cron‑style helper.
