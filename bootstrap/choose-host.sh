#!/usr/bin/env bash
set -euo pipefail

echo "Доступные профили:"
echo "1) default"
echo "2) thinkpad"
echo "3) desktop"
echo "4) cf19"
echo "5) huawei"

read -r -p "Введите номер (1-4): " choice

case "$choice" in
  1) echo "default" ;;
  2) echo "thinkpad" ;;
  3) echo "desktop" ;;
  4) echo "cf19" ;;
  5) echo "huawei" ;;
  *) echo "Неверный выбор. Используйте 1, 2, 3, 4 или 5." >&2; exit 1 ;;
esac
