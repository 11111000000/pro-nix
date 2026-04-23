Title: Mesh overlay (Headscale/WireGuard or Yggdrasil) и безопасное распределение creds

Цель
Обеспечить надёжную связность между хостами pro-nix даже при ограниченном/блокированном интернете, а также безопасную доставку зашифрованных credentials/ключей для автоподключения сервисов (Samba, WireGuard).

Требования
- Хосты должны иметь стабильные адреса/имена на overlay-сети.
- Доставка ключей/creds должна быть зашифрована и операторская (не хранить секреты в репозитории).
- Процесс должен быть воспроизводим и документирован.

Компоненты решения
1) Mesh layer
   - Headscale + WireGuard: operator-hosted headscale контроллер; clients register, operator выдаёт join-keys и конфиги; клиенты запускают wg-quick.
   - Yggdrasil: п2п overlay без центрального контроллера; пригоден для определённых сценариев, даёт стабильные IPv6 адреса.

2) Secure creds distribution
   - Оператор готовит зашифрованный bundle (GPG/age) с per-host файлами creds (например, /etc/samba/creds.d/huawei.gpg и /etc/wireguard/wg0.conf.gpg).
   - В репо храним мастер-скрипт (pro-peer-master.sh style) который передаёт зашифрованные артефакты на хосты и запускает systemd oneshot на стороне хоста, который расшифровывает их в нужные пути (scripts/pro-samba-sync-keys.sh — пример).

Процесс operator (пример)
1. Оператор генерирует creds для host huawei и шифрует: gpg -e -r host-operator -o huawei.creds.gpg huawei.creds
2. Оператор запускает: ./scripts/pro-peer-master.sh --hosts huawei.local --file ./huawei.creds.gpg (скрипт доставит зашифрованный файл и запустит remote oneshot для расшифровки и установки)
3. На хосте systemd oneshot отвечает за вызов scripts/pro-samba-sync-keys.sh --input /tmp/creds.gpg --out /etc/samba/creds.d/huawei

Headscale quickstart (схема)
1. Оператор развертывает headscale на публичном хосте (или в Docker на operator node). Конфигурация: listen address, database, etc.
2. Оператор создаёт namespace/acl и генерирует join keys: headscale nodes register ...
3. Клиенты получают конфиг wg0.conf (через зашифрованный bundle) и выполняют wg-quick up /etc/wireguard/wg0.conf

Yggdrasil quickstart (схема)
1. На каждом хосте установить yggdrasil (pkgs.yggdrasil присутствует в repo).
2. Сгенерировать конфиг: yggdrasil -genconf > /etc/yggdrasil.conf
3. Собрать список публичных ключей/peer set и распространить его через operator (зашифрованный bundle) или через заранее согласованный rendezvous.

Проверка и валидация
- Проверить overlay connectivity: ping overlay-ip или ping host.overlay
- Проверить имя resolution: при использовании headscale/consul — проверить DNS записи; при Yggdrasil — проверить IPv6 адреса и mDNS over overlay при необходимости.

Risks and mitigations
- Headscale requires reachable coordination endpoint — operator must host it on public IP or relay. Если отсутствует — Yggdrasil альтернативно.
- Распространение зашифрованных creds требует надёжного ключа оператора; процедуру rotation нужно документировать.

Integration with pro-nix
- Добавить nix module для headscale (есть базовая заготовка modules/headscale.nix). Улучшить: добавить options для persist, tls, db path и systemd native unit вместо docker run.
- Добавить pro-peer-master.sh variants для wireguard/yggdrasil creds distribution (использовать existing pro-peer-master.sh as template).
- Добавить tests/verify scripts (smoke tests) для verifying overlay and shares.
