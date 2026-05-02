#!/usr/bin/env bash
# collect-switch-logs.sh — сбор диагностической информации при switch
# Скрипт сохраняет логи в постоянную директорию, переживающую перезагрузку
set -euo pipefail

# Используем постоянную директорию вместо /tmp (который очищается при ребуте)
LOG_DIR="/home/az/pro-nix/logs/switch-diagnostics-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$LOG_DIR"

echo "=== Сбор логов до switch ===" | tee "$LOG_DIR/00-status.log"
echo "Логи будут сохранены в: $LOG_DIR" | tee -a "$LOG_DIR/00-status.log"

# 1. Логи текущей загрузки (до switch)
echo "=== Сохранение логов текущей загрузки ===" | tee -a "$LOG_DIR/00-status.log"
journalctl --boot=0 --no-pager > "$LOG_DIR/pre-switch-boot.log" 2>&1 || true
journalctl --boot=0 --no-pager | grep -E "Unbalanced|parse failure|error|Failed" > "$LOG_DIR/pre-switch-errors.log" 2>&1 || true

# 2. Проверка текущих unit-файлов
echo "=== Копирование текущих unit-файлов ===" | tee -a "$LOG_DIR/00-status.log"
mkdir -p "$LOG_DIR/units-pre"
cp -r /etc/systemd/system/tor-ensure-*.service "$LOG_DIR/units-pre/" 2>/dev/null || true
cp /etc/avahi/services/samba.service "$LOG_DIR/units-pre/" 2>/dev/null || true

# 3. Сохранение списка failed units
systemctl --failed > "$LOG_DIR/pre-switch-failed-units.log" 2>&1 || true

# 4. Выполнение switch с сохранением логов
echo "=== Выполнение switch --repair ===" | tee -a "$LOG_DIR/00-status.log"
echo "ВНИМАНИЕ: Если система перезагрузится, логи сохранены в $LOG_DIR" | tee -a "$LOG_DIR/00-status.log"

# Запускаем switch и сохраняем вывод
SWITCH_LOG="$LOG_DIR/switch-output.log"
if sudo nixos-rebuild switch --flake .#huawei --repair 2>&1 | tee "$SWITCH_LOG"; then
    echo "=== Switch прошел успешно ===" | tee -a "$LOG_DIR/00-status.log"
    
    # 5. Если switch прошел (система не перезагрузилась), собираем логи после
    echo "=== Сбор логов после switch ===" | tee -a "$LOG_DIR/00-status.log"
    journalctl --boot=0 --no-pager > "$LOG_DIR/post-switch-boot.log" 2>&1 || true
    journalctl --boot=0 --no-pager | grep -E "Unbalanced|parse failure|error|Failed" > "$LOG_DIR/post-switch-errors.log" 2>&1 || true
    
    # Копируем новые unit-файлы
    mkdir -p "$LOG_DIR/units-post"
    cp -r /etc/systemd/system/tor-ensure-*.service "$LOG_DIR/units-post/" 2>/dev/null || true
    cp /etc/avahi/services/samba.service "$LOG_DIR/units-post/" 2>/dev/null || true
    
    # Проверяем failed units
    systemctl --failed > "$LOG_DIR/post-switch-failed-units.log" 2>&1 || true
    
    # Запускаем проверку unit-файлов
    echo "=== Проверка unit-файлов через systemd-analyze verify ===" | tee -a "$LOG_DIR/00-status.log"
    systemd-analyze verify /etc/systemd/system/tor-ensure-bridges.service > "$LOG_DIR/verify-bridges.log" 2>&1 || true
    systemd-analyze verify /etc/systemd/system/tor-ensure-perms.service > "$LOG_DIR/verify-perms.log" 2>&1 || true
    
    echo "=== Диагностика завершена ===" | tee -a "$LOG_DIR/00-status.log"
    echo "Логи сохранены в: $LOG_DIR" | tee -a "$LOG_DIR/00-status.log"
    ls -la "$LOG_DIR" | tee -a "$LOG_DIR/00-status.log"
else
    echo "=== Switch завершился с ошибкой (возможно, система перезагрузится) ===" | tee -a "$LOG_DIR/00-status.log"
    echo "Логи сохранены в: $LOG_DIR" | tee -a "$LOG_DIR/00-status.log"
    echo "После перезагрузки проверьте логи командой: ls -lt $LOG_DIR" | tee -a "$LOG_DIR/00-status.log"
fi

# Создаем README для следующей сессии
cat > "$LOG_DIR/README.md" << 'EOF'
# Логи диагностики switch

## Если система перезагрузилась

После загрузки выполните:

```bash
# Найти логи последней попытки
LOG_DIR=$(ls -dt /home/az/pro-nix/logs/switch-diagnostics-* | head -1)
cd "$LOG_DIR"

# Посмотреть статус
cat 00-status.log

# Посмотреть ошибки switch
cat switch-output.log | grep -E "Unbalanced|parse failure|error|Failed"

# Посмотреть логи предыдущей загрузки (которая упала)
journalctl --boot=-1 --no-pager > failed-boot.log 2>&1
journalctl --boot=-1 --no-pager | grep -E "Unbalanced|parse failure|Failed to start|systemd-logind.*reboot" > failed-boot-errors.log 2>&1

# Сравнить unit-файлы
diff -u units-pre/tor-ensure-bridges.service units-post/tor-ensure-bridges.service || true
```

## Если система загрузилась

```bash
# Проверить failed units
systemctl --failed

# Проверить логи
cat "$LOG_DIR/post-switch-errors.log"
```
EOF

echo "=== README создан: $LOG_DIR/README.md ==="
