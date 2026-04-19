#!/usr/bin/env bash
# run-all-analyses.sh
# Запускает все скрипты анализа и создает отчет

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/output"

mkdir -p "$OUTPUT_DIR"

echo "=========================================="
echo "Современные техники Emacs Lisp"
echo "Для Emacs 30.2+"
echo "=========================================="
echo ""

# Check Emacs version
echo "=== Версия Emacs ==="
if command -v emacs &> /dev/null; then
    emacs --version 2>/dev/null | head -1 || echo "Невозможно определить версию"
else
    echo "Emacs не найден в PATH"
fi
echo ""

echo "=========================================="
echo "Запуск анализов..."
echo "=========================================="
echo ""

for script in check-lexical-binding.sh analyze-packages.sh analyze-settings.sh \
              analyze-functions.sh analyze-modules.sh analyze-delayed-load.sh \
              search-modern-features.sh find-cl-lib-usage.sh; do
    echo "--- $script ---"
    bash "$SCRIPT_DIR/$script" 2>&1 | tee "$OUTPUT_DIR/$(basename $script .sh).txt"
    echo ""
done

echo "=========================================="
echo "Анализ завершен"
echo "Отчеты в: docs/research/output/"
echo "=========================================="
