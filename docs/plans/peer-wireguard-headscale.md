# Plan: WireGuard + Headscale (self-hosted control plane)

Цель
-----

Построить управляемую mesh‑сеть на базе WireGuard с self‑hosted control plane (Headscale). Подходит для среды, где можно держать небольшой always‑on сервер (VPS/NAS) и требуется низкая latency и удобные имена.

Шаги
-----

1) Развернуть Headscale (control plane)

- Headscale можно поставить на небольшом VPS или NAS. Он хранит key registry и выдаёт configs для клиентов.

2) Установить WireGuard на клиентах

- На каждой машине установить wireguard, использовать предоставленные headscale ключи для подключения.

3) Регистрация и выдача конфигов

- Через headscale register создайте машины и сгенерируйте конфигурации. Headscale/clients будут получать IP и ключи.

4) Использование

- После настройки можно обращаться по internal names, которые Headscale/etcd может выдавать, либо по assigned IP.

Плюсы/минусы
------------

- + Низкая latency, высокая throughput
- + Централизованное управление ключами и ACL
- - Нужен always‑on control plane
