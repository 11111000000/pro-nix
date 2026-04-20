#!/usr/bin/env bash
set -euo pipefail

echo "Доступные профили:"
echo "1) cf19"
echo "2) huawei"

read -r -p "Введите номер (1-2): " choice

case "$choice" in
  1) echo "cf19" ;;
  2) echo "huawei" ;;
  *) echo "Неверный выбор. Используйте 1 или 2." >&2; exit 1 ;;
esac
