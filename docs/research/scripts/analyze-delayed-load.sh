#!/usr/bin/env bash
# analyze-delayed-load.sh
# Анализирует паттерны отложенной загрузки

emacs_dir="/home/zoya/pro-nix/emacs"

echo "=== Анализ отложенной загрузки ==="
echo ""

echo "--- with-eval-after-load usage ---"
grep -r "with-eval-after-load" "$emacs_dir" --include="*.el" 2>/dev/null | wc -l
grep -r "with-eval-after-load" "$emacs_dir" --include="*.el" 2>/dev/null | head -30

echo ""
echo "--- eval-after-load usage ---"
grep -r "eval-after-load" "$emacs_dir" --include="*.el" 2>/dev/null | wc -l

echo ""
echo "--- delay-load usage ---"
grep -r "delay-load" "$emacs_dir" --include="*.el" 2>/dev/null | head -20

echo ""
echo "--- define-minor-mode usage ---"
grep -r "define-minor-mode" "$emacs_dir" --include="*.el" 2>/dev/null | wc -l
grep -r "define-minor-mode" "$emacs_dir" --include="*.el" 2>/dev/null | head -20
