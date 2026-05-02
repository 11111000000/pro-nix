#!/usr/bin/env bash
# validate-units.sh — проверка unit-файлов NixOS в Nix store
# Гарантирует, что сгенерированные unit-файлы корректны
# и при 'just switch' система не упадёт
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"

LOG="/tmp/validate-units-$(date +%s).log"
echo "=== Начало проверки unit-файлов ===" | tee "$LOG"

# 1. Сборка etc (unit-файлы генерируются здесь)
echo "" | tee -a "$LOG"
echo "1. Сборка etc derivation..." | tee -a "$LOG"

# Принудительно удаляем старые результаты
rm -f ./result

if ! nix --extra-experimental-features 'nix-command flakes' build .#nixosConfigurations.huawei.config.system.build.etc 2>&1 | tee -a "$LOG"; then
  echo "ОШИБКА: Сборка etc не удалась" | tee -a "$LOG"
  exit 1
fi

# Получение пути к собранному etc через ./result
if [ ! -L "./result" ]; then
  echo "ОШИБКА: ./result не найден после сборки" | tee -a "$LOG"
  exit 1
fi

ETC_STORE="$(readlink -f ./result)/etc"
echo "etc store path: $ETC_STORE" | tee -a "$LOG"

if [ ! -d "$ETC_STORE/systemd/system" ]; then
  echo "ОШИБКА: $ETC_STORE/systemd/system не существует" | tee -a "$LOG"
  exit 1
fi

# 2. Проверка Unbalanced quoting в unit-файлах
echo "" | tee -a "$LOG"
echo "2. Проверка Unbalanced quoting..." | tee -a "$LOG"
if grep -r "Unbalanced quoting" "$ETC_STORE/systemd/system/" 2>/dev/null | tee -a "$LOG"; then
  echo "ОШИБКА: Найдено Unbalanced quoting!" | tee -a "$LOG"
  exit 1
else
  echo "Unbalanced quoting: не найдено" | tee -a "$LOG"
fi

# 3. Проверка parse failure в avahi файлах
echo "" | tee -a "$LOG"
echo "3. Проверка parse failure в avahi..." | tee -a "$LOG"
if grep -r "parse failure" "$ETC_STORE/avahi/" 2>/dev/null | tee -a "$LOG"; then
  echo "ОШИБКА: Найдено parse failure!" | tee -a "$LOG"
  exit 1
else
  echo "parse failure: не найдено" | tee -a "$LOG"
fi

# 4. Проверка конкретных unit-файлов
echo "" | tee -a "$LOG"
echo "4. Проверка конкретных unit-файлов..." | tee -a "$LOG"
FAILED=0

check_unit_file() {
  local unit="$1"
  local file="$ETC_STORE/systemd/system/${unit}.service"
  
  if [ ! -f "$file" ]; then
    echo "ПРЕДУПРЕЖДЕНИЕ: $file не найден" | tee -a "$LOG"
    return 0
  fi
  
  echo "Проверка $unit.service..." | tee -a "$LOG"
  
  # Проверка на лишние кавычки в ExecStart
  if grep "ExecStart" "$file" | grep -q "'\"'"; then
    echo "ОШИБКА: Найдены лишние кавычки в ExecStart для $unit" | tee -a "$LOG"
    grep "ExecStart" "$file" | tee -a "$LOG"
    return 1
  fi
  
  # Проверка через systemd-analyze (если доступно)
  if command -v systemd-analyze &>/dev/null; then
    if ! systemd-analyze verify "$file" 2>&1 | tee -a "$LOG"; then
      echo "ОШИБКА: systemd-analyze verify не прошёл для $unit" | tee -a "$LOG"
      return 1
    fi
  fi
  
  echo "$unit: OK" | tee -a "$LOG"
  return 0
}

check_unit_file "tor-ensure-bridges" || FAILED=1
check_unit_file "tor-ensure-perms" || FAILED=1
check_unit_file "pro-peer-sync-keys" || FAILED=1

# 5. Проверка XML для avahi samba.service
echo "" | tee -a "$LOG"
echo "5. Проверка avahi samba.service XML..." | tee -a "$LOG"
SAMBA_FILE="$ETC_STORE/avahi/services/samba.service"
if [ -f "$SAMBA_FILE" ]; then
  # Проверка: файл должен начинаться с <?xml
  if head -1 "$SAMBA_FILE" | grep -q '<?xml'; then
    echo "samba.service XML: начало корректное" | tee -a "$LOG"
    # Проверка через xmllint (если доступно)
    if command -v xmllint &>/dev/null; then
      if ! xmllint "$SAMBA_FILE" 2>&1 | tee -a "$LOG"; then
        echo "ОШИБКА: samba.service не является валидным XML" | tee -a "$LOG"
        FAILED=1
      fi
    else
      echo "samba.service: пропущен (xmllint недоступен)" | tee -a "$LOG"
    fi
  else
    echo "ОШИБКА: samba.service не начинается с <?xml" | tee -a "$LOG"
    FAILED=1
  fi
else
  echo "ПРЕДУПРЕЖДЕНИЕ: $SAMBA_FILE не найден" | tee -a "$LOG"
fi

# 6. Проверка dry-activate
echo "" | tee -a "$LOG"
echo "6. Проверка dry-activate..." | tee -a "$LOG"
if nixos-rebuild dry-activate --flake .#huawei 2>&1 | tee -a "$LOG" | grep -q "error\|Unbalanced\|parse failure"; then
  echo "ОШИБКА: dry-activate содержит ошибки" | tee -a "$LOG"
  FAILED=1
else
  echo "dry-activate: OK" | tee -a "$LOG"
fi

# Итог
echo "" | tee -a "$LOG"
if [ "$FAILED" -eq 0 ]; then
  echo "=== ВСЕ ПРОВЕРКИ UNIT-ФАЙЛОВ ПРОЙДЕНЫ УСПЕШНО ===" | tee -a "$LOG"
  rm -f "$LOG"
  exit 0
else
  echo "=== НЕКОТОРЫЕ ПРОВЕРКИ НЕ ПРОЙДЕНЫ ===" | tee -a "$LOG"
  echo "Лог сохранён: $LOG"
  exit 1
fi
