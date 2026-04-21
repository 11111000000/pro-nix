<!-- Русский: комментарии и пояснения оформлены в стиле учебника -->
# WireGuard + Headscale: план развертывания (control plane + клиенты)

Цель
-----

Дать детальный план развертывания Headscale (self‑hosted control plane) и подключения клиентов WireGuard для быстрой, управляемой mesh‑сети между pro‑nix хостами.

Предпосылки
-----------

- Нужен небольшой always‑on host: VPS или домашний NAS с публичным IP для Headscale.
- Доступ к этой машине и умение деплоить docker/flake сервисы.

Компоненты
----------

- Headscale (control plane) — registry + names + ACL.
- WireGuard клиент (на хостах) — low latency mesh.
- Optionally: DNS (Consul) or /etc/hosts managed by Headscale hooks for human names.

Шаги
-----

1) Развернуть Headscale

- Установить Headscale на VPS/NAS. Можно использовать docker image или NixOS module.
- Сгенерировать и сохранить админ ключ для Headscale.

2) Создать namespace и register nodes

- Через headscale CLI создать machines и получить join keys.

3) Конфиг клиентов

- На каждом клиенте настроить wireguard package и добавить конфиг, полученный от headscale.
- Настроить systemd service для поднятия интерфейса и маршрутизации.

4) Routing и имена

- Headscale может выдавать IP адреса; можно сводить имена в /etc/hosts или использовать lightweight DNS.

5) Безопасность

- Хранить Headscale server key и db offsite; защитить доступ к control plane (TLS, firewall).

6) DR и rotate

- Процедура rotate: удалить машину из headscale, сгенерировать новый key, обновить на клиенте.

Примеры команд
---------------

- Headscale quickstart: https://github.com/juanfont/headscale

Мониторинг
----------

- Настроить health checks и alert при не‑доступности Headscale.
