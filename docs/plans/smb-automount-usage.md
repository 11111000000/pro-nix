Title: SMB automount — инструкция и ограничения

Автоматическое монтирование (automount) удобно, но есть важный практический нюанс: systemd системные юниты не имеют интерактивного tty и не могут запросить пароль у пользователя. Поэтому порядок действий для безопасного включения automount следующий.

1) Однократный ввод и сохранение пароля
- Самый простой и безопасный путь: один раз выполнить интерактивную команду, сохранить креды и затем включать автоматическое монтирование.
- Команда (однократно):
  sudo ./scripts/mount-smb.sh mount <host>
- При запросе введите username и password и ответьте 'Y' на вопрос о сохранении. Скрипт положит creds в /etc/samba/creds.d/<host> с правами 600 и владельцем root:root.

2) Ручное создание файла кредов (альтернатива)
- Создайте файл /etc/samba/creds.d/<host> с содержимым:
  username=youruser
  password=yourpass
  domain=WORKGROUP
- Установите права: sudo chown root:root /etc/samba/creds.d/<host> && sudo chmod 600 /etc/samba/creds.d/<host>

3) Включение automount (system-level)
- Примените конфигурацию: sudo nixos-rebuild switch
- Включите automount для хоста (пример huawei):
  sudo systemctl enable --now smb-mount@huawei.automount
- После этого доступ к /mnt/hosts/huawei (ls, cd, GUI) вызовет systemd и запустит монтирование через smb-mount@huawei.service.

4) Отладка
- Проверить статус юнитов:
  sudo systemctl status smb-mount@huawei.automount
  sudo systemctl status smb-mount@huawei.service
- Журналы:
  sudo journalctl -u smb-mount@huawei.service -n 200
  sudo journalctl -u smb-mount@huawei.automount -n 200
- Проверить файл кредов и права доступа: ls -l /etc/samba/creds.d/huawei

5) Безопасность и рекомендации
- Автоматический автокомпонент работает только при наличии неконфиденциальных (root‑only) файлов кредов; система НЕ будет интерактивно запрашивать пароль при first-mount запуске в контексте systemd.
- Если нежелательно хранить пароли в явном виде на диске, рассмотреть зашифрованный файл /etc/samba/creds.d/<host>.gpg и автоматическую расшифровку (см. ops-pro-peer-sync-keys.sh как пример). Это потребует расширения модульного flow и операторской работы.
- Альтернатива: использовать systemd user units (user scope) и хранить credentials в пользовательской учётной записи, но это сложнее для мульти‑user систем и менее прямолинейно для глобальных точек монтирования.

6) Отключение и откат
- Выключить automount и отмонтировать:
  sudo systemctl disable --now smb-mount@huawei.automount
  sudo systemctl stop smb-mount@huawei.service || true
  sudo umount /mnt/hosts/huawei || true

7) Примеры типичных ошибок
- "Permission denied" при mount: проверьте creds, их формат и права
- "No route to host / name not resolved": avahi или nss-mdns не работают — проверьте avahi-daemon и установку nss-mdns
- mount висит/зависает: возможно, проблемы с сетью или сервером — увеличьте TimeoutIdleSec или выключите automount

Резюме
- Рабочий порядок: один раз сохранить креды интерактивно или вручную, затем включить automount. Это даёт удобство и минимизирует необходимость интерактивных операций в systemd.
