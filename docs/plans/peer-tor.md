# Plan: Tor Hidden Services (reachability без port‑forwarding)

Цель
-----

Обеспечить доступ к хостам pro‑nix из интернета и между машинами без необходимости проброса портов — с приватностью и обходом NAT — через Tor hidden services (.onion).

Шаги (рекомендуемый быстрый путь)
---------------------------------

1) Установка Tor (NixOS)

Добавьте в `configuration.nix`:

```nix
services.tor = {
  enable = true;
  package = pkgs.tor;
};
```

2) Конфигурация hidden service для SSH

Добавьте в `/etc/tor/torrc` (или соответствующий путь в NixOS option `services.tor.extraConfig`) строку:

```
HiddenServiceDir /var/lib/tor/ssh_hidden_service
HiddenServicePort 22 127.0.0.1:22
```

После перезапуска Tor файл `/var/lib/tor/ssh_hidden_service/hostname` будет содержать .onion адрес.

3) Подключение через Tor

Простейший пример SSH через Tor (локально установленный Tor SOCKS5 proxy на 127.0.0.1:9050):

```bash
ssh -o 'ProxyCommand nc -x 127.0.0.1:9050 %h %p' user@abcdef.onion
```

4) Безопасность

- Храните HiddenServiceDir с правами 700; приватные ключи не коммитите.
- Обмен .onion адресами делайте защищённо (GPG, Signal, лично).

Плюсы/минусы
------------

- + Работает через NAT без port forwarding
- + Приватность: реальный IP не раскрывается
- - Больше latency, не самый высокий throughput

Когда переходить к этому
------------------------

Если вам нужна глобальная доступность без изменения роутера и с приоритетом приватности — Tor — хороший выбор.
