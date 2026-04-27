#!/usr/bin/env bash
# test-in-container.sh — тестирование активации в nixos-container
# Использует `nixos-container run` для запуска одноразового контейнера
set -euo pipefail

LOG_DIR="/home/az/pro-nix/logs/container-test-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$LOG_DIR"

echo "=== Тестирование в nixos-container ===" | tee "$LOG_DIR/status.log"
echo "Логи будут сохранены в: $LOG_DIR" | tee -a "$LOG_DIR/status.log"

# Проверяем, что nixos-container доступен
if ! command -v nixos-container &> /dev/null; then
    echo "ОШИБКА: nixos-container не найден." | tee -a "$LOG_DIR/status.log"
    exit 1
fi

# Запускаем контейнер одноразово (run создает, запускает и удаляет)
echo "=== Запуск контейнера (одноразовый) ===" | tee -a "$LOG_DIR/status.log"
sudo nixos-container run --flake .#huawei 2>&1 | tee "$LOG_DIR/container-output.log" &
CONTAINER_PID=$!

# Ждем загрузки (даем 60 секунд)
echo "=== Ожидание загрузки (60s) ===" | tee -a "$LOG_DIR/status.log"
sleep 60

# Проверка 1: unit-файлы проходят systemd-analyze verify
echo "=== Проверка unit-файлов ===" | tee -a "$LOG_DIR/status.log"
sudo nixos-container run --flake .#huawei -- systemd-analyze verify /etc/systemd/system/tor-ensure-bridges.service 2>&1 | tee "$LOG_DIR/verify-bridges.log"
sudo nixos-container run --flake .#huawei -- systemd-analyze verify /etc/systemd/system/tor-ensure-perms.service 2>&1 | tee "$LOG_DIR/verify-perms.log"

# Проверка 2: отсутствие Unbalanced quoting в логах
echo "=== Проверка Unbalanced quoting ===" | tee -a "$LOG_DIR/status.log"
UNBALANCED=$(sudo nixos-container run --flake .#huawei -- journalctl --boot=0 | grep -i 'Unbalanced quoting' || true)
if [ -n "$UNBALANCED" ]; then
    echo "ОШИБКА: Найден Unbalanced quoting:" | tee -a "$LOG_DIR/status.log"
    echo "$UNBALANCED" | tee -a "$LOG_DIR/status.log"
    sudo kill $CONTAINER_PID 2>/dev/null || true
    exit 1
else
    echo "Unbalanced quoting: OK" | tee -a "$LOG_DIR/status.log"
fi

# Проверка 3: отсутствие parse failure в avahi
echo "=== Проверка parse failure ===" | tee -a "$LOG_DIR/status.log"
PARSE_ERRORS=$(sudo nixos-container run --flake .#huawei -- journalctl --boot=0 | grep -i 'parse failure' || true)
if [ -n "$PARSE_ERRORS" ]; then
    echo "ОШИБКА: Найден parse failure:" | tee -a "$LOG_DIR/status.log"
    echo "$PARSE_ERRORS" | tee -a "$LOG_DIR/status.log"
    sudo kill $CONTAINER_PID 2>/dev/null || true
    exit 1
else
    echo "parse failure: OK" | tee -a "$LOG_DIR/status.log"
fi

# Проверка 4: ExecStart содержит явный путь
echo "=== Проверка ExecStart ===" | tee -a "$LOG_DIR/status.log"
EXEC_BRIDGES=$(sudo nixos-container run --flake .#huawei -- grep "ExecStart" /etc/systemd/system/tor-ensure-bridges.service 2>/dev/null || echo "")
if echo "$EXEC_BRIDGES" | grep -q "/nix/store"; then
    echo "ExecStart (bridges): OK" | tee -a "$LOG_DIR/status.log"
else
    echo "ОШИБКА: ExecStart (bridges) не содержит /nix/store: $EXEC_BRIDGES" | tee -a "$LOG_DIR/status.log"
    sudo kill $CONTAINER_PID 2>/dev/null || true
    exit 1
fi

# Останавливаем контейнер
echo "=== Очистка ===" | tee -a "$LOG_DIR/status.log"
sudo kill $CONTAINER_PID 2>/dev/null || true

echo "=== ВСЕ ПРОВЕРКИ ПРОЙДЕНЫ ===" | tee -a "$LOG_DIR/status.log"
echo "Логи сохранены в: $LOG_DIR"
exit 0
