<!-- Русский: комментарии и пояснения оформлены в стиле учебника -->
# Plan: ncps / nginx local proxy (локальный кеш и proxy)

Цель
-----

Организовать локальный HTTP‑proxy/caching для Nix binary cache (чтобы сократить повторные загрузки из cache.nixos.org в LAN).

Шаги
-----

1) Выбрать реализацию: ncps (рекомендуется) или nginx proxy.

2) Развертывание (Docker / NixOS module)

- ncps: запустить контейнер или NixOS сервис по инструкции проекта.
- nginx: использовать proxy_cache_path и proxy_pass к https://cache.nixos.org.

3) Настроить клиентов

- Добавить в `nix.conf` substituter `http://cache.local:8501` перед `https://cache.nixos.org`.

4) Политики

- Настроить размеры кеша, GC и мониторинг.
