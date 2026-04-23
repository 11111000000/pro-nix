Title: Простая и надёжная схема обнаружения хостов и on‑demand монтирования SMB

Краткое содержание
1) Цель: обеспечить, чтобы ноутбуки в одной LAN находили друг друга по имени (hostname.local) и чтобы оператор мог оперативно монтировать сетевые шары других хостов на запрос. Решение должно быть простым, детерминированным и безопасным.
2) Вкратце: используем Avahi (mDNS) + nss-mdns для обнаружения/разрешения имён и cifs-utils + небольшой набор скриптов (on‑demand) для монтирования. Автоматический постоянный автоконнект не включаем по умолчанию — это уменьшает риск зависания, утечек учётных данных и побочных эффектов при смене сети.

История изменений в репозитории (коротко)
- Добавлен пакет cifs-utils в system-packages (system-packages.nix).
- Добавлен pkgs.nss-mdns в configuration.nix (гарантирует поддержку mDNS в NSS).
- Добавлен скрипт scripts/mount-smb.sh (discover, mount, umount, mount-all).
- Добавлен nix/modules/pro-smb-mount.nix — заготовка systemd user template (placeholder).

Тезис — что предлагается (почему это хорошо)
- Avahi + nss-mdns: простая, проверенная служба для mDNS/DNS‑SD. Позволяет именам вида host.local работать без центрального DNS.
- cifs-utils: нужно, чтобы монтировать CIFS/SMB-шары стандартно (mount.cifs). Это дешевле по зависимостям, чем доп. GUI или FUSE-обёртки.
- On‑demand скрипты: монтирование только при явном запросе уменьшает вероятность неожиданных зависимостей, проблем при отрыве от сети, и даёт явный контроль над правами и точками монтирования.

Антитезис — критический разбор и риски
- mDNS не всегда работает через разные маршрутизаторы и VLAN. Риски: изоляция сетей (guest Wi‑Fi), IGMP/Multicast фильтрация, или настройки AP, которые блокируют mDNS. Решение: резерв — использование IP адресов/статических записей или туннелей (WireGuard/Yggdrasil) для дальнего доступа.
- Автоматический autoload/automount может привести:
  - к ошибкам при загрузке, если smbd/nmbd/avahi ещё не подняты;
  - к блокировкам файловой системы при наличии зависших CIFS соединений (особенно через Wi‑Fi);
  - к раскрытию учётных данных, если креды хранятся централизованно без ограничения прав.
- SMB — сложный протокол с версионной совместимостью (SMB1/2/3), нюансами подписей и шифрования. Жёсткие политики (smb signing/encryption/ntlm off) повышают безопасность, но сокращают совместимость (старые Android/Windows).

Синтез — компромиссное, простое + надёжное предложение
- Оставить Avahi + nss-mdns включёнными (это уже предусмотрено в repo). Это покрывает большинство случаев, когда хосты в одной LAN.
- По умолчанию использовать поведение "on‑demand": скрипт/scripts/mount-smb.sh. Не подключать автоматическое монтирование при загрузке.
- Если нужен автоподключаемый сценарий — реализовать через systemd user templates + systemd.automount с таймаутами и Restart=on-failure ограниченным числом попыток. Добавлять автоподключение только как опцию в host overlay, не глобально.
- Credentials: per-host файлы в /etc/samba/creds.d/<host> с правами 600. Не хранить пароли в git или явно в репо. Рассмотреть секреты GPG/age через operator-managed flow (pro-peer уже использует GPG для authorized_keys).

Пошаговый простой план (docs/plans/… — rollout)
Цель: развернуть безопасный on‑demand SMB+discovery на всех ноутбуках коллекции pro-nix.

Шаг 0 — проверка перед rollout (локально)
- Запустите diagnostics: ./scripts/run-samba-diagnostics.sh и убедитесь, что avahi-daemon запущен и не выдаёт предупреждений типа "No NSS support for mDNS".

Шаг 1 — применить системную конфигурацию
- Выполнить на хосте: sudo nixos-rebuild switch --flake .#<host> (или ваш обычный workflow). Это установит nss-mdns, cifs-utils и активирует avahi (если он не включён локально).

Шаг 2 — проверка базовой видимости
- На машине A выполните: avahi-browse -rt _smb._tcp
- На машине B: ping hostA.local
- Убедитесь, что вывод avahi показывает сервисы на порту 445 для каждого хоста. Если нет — проверить мультикаст/сетевую политику AP.

Шаг 3 — ручное тестовое монтирование
- На машине A попробуйте: ./scripts/mount-smb.sh discover
- Затем: sudo ./scripts/mount-smb.sh mount huawei
- Проверить: mount | grep /mnt/hosts && ls -la /mnt/hosts/huawei
- Логирование: journalctl -u avahi-daemon -n 200; journalctl -u samba-smbd -n 200

Шаг 4 — ввод в эксплуатацию и документирование у пользователей
- Объяснить пользователям команду: ./scripts/mount-smb.sh mount <host>
- Документировать процедуру создания кредов: /etc/samba/creds.d/<host> (root:root, 600) с форматом:
  username=...\n  password=...\n  domain=WORKGROUP
- Для сидящих в защищённой сети: можно использовать общую read-only public шарУ (srv/samba/public) и guest mount.

Шаг 5 — дополнительные опции (опционально)
- Если нужно autoload: реализовать systemd.user unit + .automount шаблон с ограничением RestartSec и IdleTimeout. Включать per-host через host overlay (local.nix).
- Для мобильных клиентов/Android: возможно потребуется временно снизить требования signing/encryption на тестовой ветке, но документировать риски. Предпочтительнее — использовать WebDAV/SFTP или экспонировать отдельную public шарУ с минимальными требованиями.

Verification / Proof
- Команды, которые должны успешно пройти после rollout:
  - avahi-browse -rt _smb._tcp  (показывает все хосты)
  - ping host.local (имя разрешается)
  - smbclient -L //host.local -N (показывает shares)
  - ./scripts/mount-smb.sh mount <host> (монтирование работает)
  - ./scripts/run-samba-diagnostics.sh — нет критических ошибок

Rollback
- Если новый пакет/скрипты ломают workflow — выполнить rollback nixos-rebuild to previous generation: sudo nixos-rebuild switch --rollback или вернуться на прежний коммит в репозитории и выполнить rebuild.

Миграции и заметки оператора
- Перевод хостов с ручной настройки на pro-nix схему требует: гарантировать, что avahi запущен и nss-mdns установлен; проверить firewall/ACL на роутере/AP; при необходимости — добавить host-overlays с per-host credentials.
- Не храните креды в Git; пользуйтесь /etc/pro-peer и GPG flow (pro-peer already used for authorized_keys). Можно расширить эту модель для зашифрованных /etc/samba/creds.d/<host>.gpg и автоматической расшифровки при установке (аналогично pro-peer-sync-keys.sh).

Альтернативы (кратко)
- SSHFS (sshfs): проще для UNIX-to-UNIX, использует SSH keys, безопаснее в сетях без SMB. Минусы: не поддерживается Windows/Android как SMB; требует fuse и может потребовать дополнительной конфигурации.
- NFS: прост для POSIX, но сложнее безопасно в untrusted Wi‑Fi и требует экспорта/ACL.
- Centralized file server (NAS): упростит клиентские настройки, но добавит single point of failure и требует инфраструктуры.

Заключение (диалектическая сводка)
- Тезис (автоматизация и обнаружение) корректен: mDNS + avahi дают удобство. Антитезис (безопасность, сеть и стабильность) серьёзен и требует отказа от агрессивного автоподключения. Синтез: сохраняем mDNS + on‑demand монтирование как default, добавляем документацию, per-host credentials и опциональную, осторожно включаемую systemd automount инфраструктуру по мере надёжности сети.

Предложение по следующему шагу
- Принять этот документ как план в docs/plans/ и если согласны — я добавлю:
  1) пример systemd.user automount template (опционально), привязываемый в hosts/* при необходимости;
  2) поддержку зашифрованных creds (/etc/samba/creds.d/*.gpg) с аналогичным pro-peer-sync-keys.sh flow для развёртывания секретов.

Автор: OpenCode (внес изменения в репо: system-packages.nix, configuration.nix, scripts/mount-smb.sh, nix/modules/pro-smb-mount.nix)
