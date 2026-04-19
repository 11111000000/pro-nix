#!/usr/bin/env bash
# analyze-modules.sh
# Анализирует структуру модулей

emacs_dir="/home/zoya/pro-nix/emacs/base/modules"

echo "=== Анализ модулей ==="
echo ""

echo "--- Всего модулей ---"
ls -1 "$emacs_dir"/*.el 2>/dev/null | wc -l

echo ""
echo "--- Модули и их размеры ---"
ls -lh "$emacs_dir"/*.el 2>/dev/null | awk '{print $9, $5}'

echo ""
echo "--- Структура модулей (provide/require) ---"
for f in "$emacs_dir"/*.el; do
    if [ -f "$f" ]; then
        echo "--- $(basename $f) ---"
        grep -E "(provide|require)" "$f" 2>/dev/null || echo "нет provide/require"
        echo ""
    fi
done
