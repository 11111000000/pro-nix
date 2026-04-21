<!-- Русский: комментарии и пояснения оформлены в стиле учебника -->
# Plan: Avahi / mDNS (локальная сеть)

Цель
-----

Обеспечить автоматическое разрешение имён вида `host.local` внутри одной локальной сети (Wi‑Fi) без ручного конфигурирования DNS.

Шаги
-----

1) Установка (NixOS)

Добавьте в `configuration.nix` для каждой машины:

```nix
services.avahi = {
  enable = true;
  publish = {
    # publish local services if needed
  };
};
networking.hostName = "cf19"; # индивидуально
```

В этом репозитории можно включить модуль `modules/pro-peer.nix`, который включает Avahi и базовые настройки SSH. Пример включения (в `configuration.nix`):

```nix
imports = [ ./modules/pro-peer.nix ];
# Затем в секции конфигурации хоста можно включить:
pro-peer.enable = true;
```

2) Проверка

- `systemctl enable --now avahi-daemon` (если не NixOS)
- `ping cf19.local`
- `avahi-browse -rt _workstation._tcp`

3) Разработка политики

- Решите, какие службы публикуются (SSH, HTTP). Например, Avahi может рекламировать SSH сервисы через DNS‑SD.
- Следите за конфликтами имён и возможностью хостов менять hostname при смене роли.

Преимущества
-------------

- Простой и устойчивый способ для LAN discovery.

Ограничения
------------

- Не работает между разными сетями или через интернет.
