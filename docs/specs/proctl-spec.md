<!-- Русский: комментарии и пояснения оформлены в стиле учебника -->
Proctl — спецификация JSON API
=================================

Цель
----
proctl — это тонкий CLI‑адаптер между UI (Textual / Emacs) и логикой репозитория
(скрипты, systemd, nixos-rebuild и т.д.). Он даёт единый JSON‑ориентированный
интерфейс: UI вызывает proctl, получает JSON и отображает результат пользователю.

Основные принципы
-----------------
- Все команды по умолчанию работают в режиме preview/dry‑run, если это потенциально
  опасная операция (запись в /etc, смена хоста, рестарт системных сервисов и т.д.).
- proctl логирует все операции (audit) в ~/.local/share/pro-nix/actions.log.
- proctl поддерживает локальное и удалённое исполнение (через SSH): host spec
  может быть `local` или `ssh:user@host[:port]`.

Общий формат ответов
--------------------
- Успех: JSON объект, например:

  {
    "result": "ok",
    "data": { ... }
  }

- Ошибка: exit code != 0 и JSON с полем `error`:

  {
    "error": "описание ошибки"
  }

Команды (MVP)
-------------
- list-hosts
  - Описание: вернуть список известных/сконфигурированных хостов.
  - Выход: { "hosts": [{"name":"local","type":"local","desc":"Локальная машина"}, ...] }

- host-status --host <spec>
  - Описание: состояние host (проактивные проверки): systemd services, ssh listening
  - Выход: { "host": "local", "services": [{"unit":"avahi-daemon","active":true}, ...], "ssh_listening": true }

- list-services --host <spec>
  - Описание: список systemd unit'ов (services) на хосте
  - Выход: { "services": [{"unit":"sshd.service","active":"active","description":"OpenSSH server"}, ...] }

- service-action --host <spec> --unit <unit> --action start|stop|restart|status [--dry-run]
  - Dry‑run: возвращает команду, которая будет выполнена
    { "preview": "systemctl restart sshd.service" }
  - Run: выполняет команду и возвращает stdout/stderr/rc (или путь к файлу с output при streaming)

- run-script --host <spec> --script <key> [--dry-run]
  - script key мапится на набор безопасных операций (pro-peer-sync-keys, backup-hiddenservice, run-samba-diagnostics)
  - Dry‑run: возвращает команду
  - Run: выполняет и возвращает result + out_path если есть

- upload-file --host <spec> --src <local> --dst <remote> [--owner root:root] [--mode 0600] [--dry-run]
  - Для local: делает install/cp с sudo
  - Для remote: делает scp -> sudo mv на целевой машине
  - Выход: preview или результат выполнения

- set-hostname --host <spec> --hostname <name> [--dry-run]
  - Устанавливает hostname через hostnamectl. По умолчанию использует pkexec при локальном запуске
    или выполняется по SSH удалённо (через sudo на целевой стороне). Возвращает preview или результат.

- diagnostics --host <spec> --which <all|samba|pro-peer|emacs>
  - Собирает bundle и возвращает путь к архиву

- rebuild --host <spec> --flake <flake> --preview|--run
  - preview: возвращает команду и предупреждения
  - run: выполняет nixos-rebuild switch и streams output (возвращает out_path)

Streaming
---------
Для длинных операций proctl генерирует временный файл и возвращает его путь в поле `out_path`.
UI может открыть этот файл (или tail). Для future work можно добавить JSON‑L streaming channel.

Audit log
---------
proctl пишет записи в ~/.local/share/pro-nix/actions.log в формате JSON‑line; записи содержат
timestamp, user, host, action, cmd (previewed), dry_run flag и rc/summary по завершении.

Безопасность
------------
- proctl не хранит приватные ключи в явном виде.
- Для операций с повышенными привилегиями proctl запускает pkexec/sudo по запросу UI
  (опция `--as-root` или UI подтверждение). proctl делает бэкап файлов перед перезаписью.
