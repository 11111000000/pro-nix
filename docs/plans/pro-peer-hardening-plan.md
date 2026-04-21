# План жёсткой безопасности и развертывания pro-peer

Цель
-----

Пошаговый план по внедрению, тестированию и поддержке безопасной peer‑сети для pro‑nix, при условии, что репозиторий публичный и секреты хранятся отдельно.

Фазы
-----

Фаза 0 — подготовка секретов (обязательно, оффлайн)

1. Сгенерировать GPG keypair для шифрования `authorized_keys` (использовать hardware token по возможности).
2. Сформировать файл `authorized_keys` содержащий публичные ключи доверенных операторов.
3. Зашифровать: `gpg --output authorized_keys.gpg --encrypt --recipient '<GPG_ID>' authorized_keys`.
4. Передать `authorized_keys.gpg` на каждый хост (scp/rsync из безопасного хранилища). Не хранить `.gpg` в публичном репо.

Фаза 1 — базовое развертывание (LAN trust)

1. Включить `pro-peer.enable = true` на всех хостах (выполнено — модуль присутствует в `modules/pro-peer.nix`).
2. Включить `pro-peer.enableKeySync = true` и разместить `authorized_keys.gpg` в `/etc/pro-peer/authorized_keys.gpg`.
   - Скрипт `scripts/pro-peer-sync-keys.sh` теперь tolerant: если файл отсутствует, юнит завершится успешно (no-op).
   - Рекомендуется операторный playbook `scripts/rotate-authorized-keys.sh` (еще не реализован) для безопасной доставки и ротации.
3. Запустить и проверить systemd сервис `pro-peer-sync-keys.service` и timer (systemctl status/journalctl). Убедиться, что
   файл `/var/lib/pro-peer/authorized_keys` создан и имеет права 600 root:root после успешной расшифровки.
4. Проверить Avahi: `ping host.local` из другого хоста. Если `avahi-daemon` ранее падал из‑за отсутствия
   runtime каталога `/run/avahi-daemon`, модуль теперь добавляет tmpfiles правило для его создания (см. modules/pro-peer.nix).
5. Проверить SSH из LAN: `ssh user@host.local` — должен работать только по ключу. Для специализированных ключей можно
   использовать forced-command acceptor (`scripts/pro-peer-acceptor.sh`) чтобы ограничить разрешённые команды (например nix copy).

Фаза 2 — ограничение поверхностей атаки

1. Перевести firewall на декларативный режим в NixOS, настроить только RFC1918 для SSH.
2. Внедрить `forced-command` acceptor для привилегированных ключей и тестировать.
3. Запретить AllowTcpForwarding/AgentForwarding интегрально (уже в extraConfig).

Фаза 3 — внешняя доступность (опции)

Опция A — Tor Hidden Service (рекомендуется если не хотите проброс портов)
- Включить `pro-peer.allowTorHiddenService = true` на назначенных хостах.
- Настроить backup hidden service и хранить encrypted backup offsite.

Опция B — WireGuard + Headscale (нужен control plane)
- Развернуть Headscale на VPS/NAS.
- Подать конфиги WireGuard на хосты, управлять именами через Headscale.

Опция C — Yggdrasil mesh
- Включить `pro-peer.enableYggdrasil = true` на хостах, обменяться peer конфигурациями.

Фаза 4 — аудит и мониторинг

1. Настроить логирование SSH событий (`/var/log/auth.log`), настроить rsyslog/journalctl retention и logrotate.
2. Настроить alert при изменении `/var/lib/pro-peer/authorized_keys` (auditd or inotify watcher) и при превышении дискового порога.

Фаза 5 — процедуры реагирования

1. Rotate GPG key: инструкция для генерации нового ключа и повторного шифрования authorized_keys.gpg.
2. Revoke compromised SSH keys: инструкция для удаления записи из plaintext authorized_keys и пересинхронизации.

Контрольные чек‑пойнты

- После каждой фазы выполнить security review и smoke tests (SSH from LAN, Avahi discovery, log checks).
