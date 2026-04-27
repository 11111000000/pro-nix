#!/usr/bin/env bash
# safe-switch.sh — безопасный switch с сохранением логов
# Использует dry-activate для проверки и сохраняет логи перед switch
set -euo pipefail

LOG_DIR="/home/az/pro-nix/logs/switch-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$LOG_DIR"

echo "=== Безопасный switch ===" | tee "$LOG_DIR/00-status.log"
echo "Логи: $LOG_DIR" | tee -a "$LOG_DIR/00-status.log"

# Шаг 1: Проверка dry-activate
echo "=== Шаг 1: dry-activate ===" | tee -a "$LOG_DIR/00-status.log"
sudo nixos-rebuild dry-activate --flake .#huawei 2>&1 | tee "$LOG_DIR/dry-activate.log"

# Шаг 2: Анализ dry-activate вывода
echo "=== Шаг 2: Анализ изменений ===" | tee -a "$LOG_DIR/00-status.log"
if grep -q "stop.*dbus-broker" "$LOG_DIR/dry-activate.log"; then
    echo "ВНИМАНИЕ: dbus-broker будет остановлен!" | tee -a "$LOG_DIR/00-status.log"
    echo "Это может привести к ребуту." | tee -a "$LOG_DIR/00-status.log"
    echo " Продолжить? (y/n)" | tee -a "$LOG_DIR/00-status.log"
    read -r answer
    if [ "$answer" != "y" ]; then
        echo "Отмена." | tee -a "$LOG_DIR/00-status.log"
        exit 1
    fi
fi

# Шаг 3: Выполнение switch с сохранением логов
echo "=== Шаг 3: Выполнение switch ===" | tee -a "$LOG_DIR/00-status.log"
echo "Логи выполнения: $LOG_DIR/switch-output.log" | tee -a "$LOG_DIR/00-status.log"

# Запускаем switch и сохраняем вывод
if sudo nixos-rebuild switch --flake .#huawei 2>&1 | tee "$LOG_DIR/switch-output.log"; then
    echo "=== SWITCH УСПЕШНО ЗАВЕРШЕН ===" | tee -a "$LOG_DIR/00-status.log"
    echo "Проверьте: systemctl --failed" | tee -a "$LOG_DIR/00-status.log"
else
    echo "=== SWITCH ЗАВЕРШИЛСЯ С ОШИБКОЙ ===" | tee -a "$LOG_DIR/00-status.log"
    echo "Если система перезагрузится, загрузитесь в generation 182." | tee -a "$LOG_DIR/00-status.log"
    echo "Логи: $LOG_DIR/switch-output.log" | tee -a "$LOG_DIR/00-status.log"
fi

echo "=== Завершено ===" | tee -a "$LOG_DIR/00-status.log"
