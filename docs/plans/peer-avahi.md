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
