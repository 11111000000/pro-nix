#!/usr/bin/env bash
# verify-units.sh — прямая проверка unit-файлов без VM
# Проверяет корректность tor-ensure-*.service и samba.service
set -euo pipefail

LOG_DIR="/home/az/pro-nix/logs/unit-verify-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$LOG_DIR"

echo "=== Проверка unit-файлов ===" | tee "$LOG_DIR/status.log"

# Сборка etc derivation
echo "Сборка etc..." | tee -a "$LOG_DIR/status.log"
nix build .#nixosConfigurations.huawei.config.system.build.etc \
    --extra-experimental-features "nix-command flakes" \
    -o "$LOG_DIR/etc-result" 2>&1 | tee "$LOG_DIR/build.log"

ETC_PATH="$LOG_DIR/etc-result/etc"

# Проверка 1: Unbalanced quoting
echo "Проверка Unbalanced quoting..." | tee -a "$LOG_DIR/status.log"
if grep -r "Unbalanced quoting" "$ETC_PATH/systemd/system/" 2>/dev/null; then
    echo "ОШИБКА: Найден Unbalanced quoting" | tee -a "$LOG_DIR/status.log"
    exit 1
else
    echo "Unbalanced quoting: OK" | tee -a "$LOG_DIR/status.log"
fi

# Проверка 2: parse failure в avahi
echo "Проверка avahi services..." | tee -a "$LOG_DIR/status.log"
if grep -r "parse failure" "$ETC_PATH/avahi/services/" 2>/dev/null; then
    echo "ОШИБКА: Найден parse failure" | tee -a "$LOG_DIR/status.log"
    exit 1
else
    echo "parse failure: OK" | tee -a "$LOG_DIR/status.log"
fi

# Проверка 3: systemd-analyze verify
echo "Проверка systemd-analyze verify..." | tee -a "$LOG_DIR/status.log"
for unit in tor-ensure-bridges.service tor-ensure-perms.service; do
    if [ -f "$ETC_PATH/systemd/system/$unit" ]; then
        if systemd-analyze verify "$ETC_PATH/systemd/system/$unit" 2>&1 | tee "$LOG_DIR/verify-$unit.log"; then
            echo "$unit: OK" | tee -a "$LOG_DIR/status.log"
        else
            echo "ОШИБКА: $unit не прошел verify" | tee -a "$LOG_DIR/status.log"
            exit 1
        fi
    else
        echo "ПРЕДУПРЕЖДЕНИЕ: $unit не найден" | tee -a "$LOG_DIR/status.log"
    fi
done

# Проверка 4: ExecStart содержит /nix/store
echo "Проверка ExecStart..." | tee -a "$LOG_DIR/status.log"
for unit in tor-ensure-bridges.service tor-ensure-perms.service; do
    if [ -f "$ETC_PATH/systemd/system/$unit" ]; then
        exec=$(grep "ExecStart" "$ETC_PATH/systemd/system/$unit" 2>/dev/null || echo "")
        if echo "$exec" | grep -q "/nix/store"; then
            echo "$unit ExecStart: OK (contains /nix/store)" | tee -a "$LOG_DIR/status.log"
        else
            echo "ОШИБКА: $unit ExecStart missing /nix/store: $exec" | tee -a "$LOG_DIR/status.log"
            exit 1
        fi
        if echo "$exec" | grep -q '/bin/sh -c'; then
            echo "ОШИБКА: $unit ExecStart contains /bin/sh -c" | tee -a "$LOG_DIR/status.log"
            exit 1
        fi
    fi
done

echo "=== ВСЕ ПРОВЕРКИ ПРОЙДЕНЫ ===" | tee -a "$LOG_DIR/status.log"
echo "Логи сохранены в: $LOG_DIR"
