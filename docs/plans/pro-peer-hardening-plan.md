<!-- Русский: комментарии и пояснения оформлены в учебном стиле (пояснения и примеры) -->
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
   - Скрипт `scripts/ops-pro-peer-sync-keys.sh` теперь tolerant: если файл отсутствует, юнит завершится успешно (no-op).
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

Дополнения — интеграция с TUI Wizard
------------------------------------

Для упрощения первичной настройки, план включает реализацию Onboarding Wizard в TUI (Textual):

1. Wizard — шаги и автоматизация
   - Шаг 1: Hostname
     - Форма: показать текущий hostname, поле для нового имени.
     - Действие: `proctl set-hostname --host <spec> --hostname <name>` (preview → confirm → run).
   - Шаг 2: Keys (authorized_keys)
     - Форма: выбор локального файла (.gpg) или ввод команды scp для доставки с remote машины.
     - Действие: `proctl upload-file --host <spec> --src <local> --dst /etc/pro-peer/authorized_keys.gpg` (preview → confirm → run).
     - После загрузки: `proctl run-script --host <spec> --script pro-peer-sync-keys`.
   - Шаг 3: Avahi / discovery
     - Проверка: `proctl host-status --host <spec>` и проверка доступности host.local.
   - Шаг 4: SSH Test
     - Тест аутентификации по ключу: `proctl ssh-test --host <spec> --user <user>` (если доступен).
   - Шаг 5: Finalize
     - Запись в локальный конфиг (~/.config/pro-nix/config.json) о завершённой настройке.

2. Remote flows
   - Wizard поддерживает режим remote: если хост задан как ssh:user@host, wizard использует scp
     и удалённое выполнение (sudo mv) для размещения файлов, и выполняет команды через SSH.

3. Безопасность Wizard
   - Все критичные шаги требуют двойного подтверждения и показывают точную команду (preview).
   - Перед перезаписью файлов создаётся локальный бэкап с меткой времени и опцией зашифровать его.

4. Acceptance тесты Wizard
   - Тест 1 (локальный): запустить Wizard для локального host, сменить hostname и загрузить тестовый authorized_keys.gpg.
   - Тест 2 (remote): добавить remote host, выполнить scp + sync; проверить, что /var/lib/pro-peer/authorized_keys появился и права 600.
