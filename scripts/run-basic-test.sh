#!/usr/bin/env bash
# run-basic-test.sh — запуск базового теста активации NixOS
# Тест проверяет отсутствие Unbalanced quoting и корректность unit-файлов
set -euo pipefail

LOG_DIR="/home/az/pro-nix/logs/basic-test-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$LOG_DIR"

echo "=== Запуск теста активации ===" | tee "$LOG_DIR/status.log"
echo "Логи будут сохранены в: $LOG_DIR" | tee -a "$LOG_DIR/status.log"

# Проверяем, что файл теста существует
TEST_FILE="/home/az/pro-nix/tests/vm/test-basic-activation.nix"
if [ ! -f "$TEST_FILE" ]; then
    echo "ОШИБКА: Файл теста не найден: $TEST_FILE" | tee -a "$LOG_DIR/status.log"
    exit 1
fi

# Запускаем тест через nix build
echo "=== Сборка и запуск теста (timeout 600s) ===" | tee -a "$LOG_DIR/status.log"
cd /home/az/pro-nix

# NixOS тесты запускаются через nix build с атрибутом checks или packages
if nix build .#checks.x86_64-linux.basic-activation-test \
    --extra-experimental-features "nix-command flakes" \
    -o "$LOG_DIR/test-result" \
    2>&1 | tee "$LOG_DIR/test-output.log"; then
    
    echo "=== ТЕСТ ПРОЙДЕН УСПЕШНО ===" | tee -a "$LOG_DIR/status.log"
    echo "Результат: $LOG_DIR/test-result" | tee -a "$LOG_DIR/status.log"
    exit 0
else
    echo "=== ТЕСТ УПАЛ ===" | tee -a "$LOG_DIR/status.log"
    echo "Анализ логов..." | tee -a "$LOG_DIR/status.log"
    
    # Ищем ошибки в логах
    grep -i "unbalanced\|parse failure\|error\|failed" "$LOG_DIR/test-output.log" \
        | head -20 | tee -a "$LOG_DIR/status.log" || true
    
    echo "Подробные логи: $LOG_DIR/test-output.log" | tee -a "$LOG_DIR/status.log"
    exit 1
fi
