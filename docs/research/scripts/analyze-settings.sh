#!/usr/bin/env bash
# analyze-settings.sh
# Анализирует паттерны настройки переменных

emacs_dir="/home/zoya/pro-nix/emacs"

echo "=== Анализ настроек (setq patterns) ==="
echo ""

echo "--- setq usage ---"
grep -r "setq" "$emacs_dir" --include="*.el" 2>/dev/null | wc -l
grep -r "setq" "$emacs_dir" --include="*.el" 2>/dev/null | head -30

echo ""
echo "--- setq-default usage ---"
grep -r "setq-default" "$emacs_dir" --include="*.el" 2>/dev/null | head -20

echo ""
echo "--- defgroup usage ---"
grep -r "defgroup" "$emacs_dir" --include="*.el" 2>/dev/null | head -20

echo ""
echo "--- defcustom usage ---"
grep -r "defcustom" "$emacs_dir" --include="*.el" 2>/dev/null | head -20
