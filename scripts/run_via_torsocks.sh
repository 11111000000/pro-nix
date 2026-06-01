#!/usr/bin/env bash
# Запуск указанного приложения через torsocks или proxychains4 (если доступен)
# Usage: ./scripts/run_via_torsocks.sh --app firefox --use torsocks

set -euo pipefail
app=""
use="torsocks"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --app) app="$2"; shift 2;;
    --use) use="$2"; shift 2;;
    --) shift; break;;
    *) echo "Unknown arg: $1" >&2; exit 2;;
  esac
done

if [ -z "$app" ]; then echo "Usage: $0 --app <command> [--use torsocks|proxychains4]" >&2; exit 2; fi

if [ "$use" = "torsocks" ]; then
  if command -v torsocks >/dev/null 2>&1; then
    exec torsocks $app "$@"
  else
    echo "torsocks не найден" >&2; exit 1
  fi
elif [ "$use" = "proxychains4" ]; then
  if command -v proxychains4 >/dev/null 2>&1; then
    exec proxychains4 $app "$@"
  else
    echo "proxychains4 не найден" >&2; exit 1
  fi
else
  echo "Unknown --use: $use" >&2; exit 2
fi
