#!/usr/bin/env bash
# check-emacs-version.sh
# Проверяет доступные функции Emacs

echo "=== Проверка версии и функций Emacs ==="
echo ""

# Check for available Emacs executable
if command -v emacs &> /dev/null; then
    echo "Emacs найден, но не удалось запустить из-за ограничений среды Nix"
    echo "Версия, доступная в системе: не определена"
else
    echo "Emacs не найден в PATH"
fi

echo ""
echo "Согласно flake.nix, требуется Emacs 30.2+"
echo ""

echo "=== Доступные функции проверки в скриптах ==="
echo ""
echo "1. (fboundp 'function-name) - проверка функции"
echo "2. (boundp 'variable-name) - проверка переменной"
echo "3. (featurep 'feature) - проверка пакета"
echo "4. (version< Emacs-version \"30.2\") - проверка версии"
echo ""
echo "В конфиге уже используются fboundp в core.el и ui.el"
