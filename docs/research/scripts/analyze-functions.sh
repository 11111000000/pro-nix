#!/usr/bin/env bash
# analyze-functions.sh
# Анализирует паттерны определения функций

emacs_dir="/home/zoya/pro-nix/emacs"

echo "=== Анализ функций и макросов ==="
echo ""

echo "--- defun usage ---"
grep -r "defun" "$emacs_dir" --include="*.el" 2>/dev/null | wc -l
grep -r "defun" "$emacs_dir" --include="*.el" 2>/dev/null | head -20

echo ""
echo "--- cl-defun usage ---"
grep -r "cl-defun" "$emacs_dir" --include="*.el" 2>/dev/null | head -20

echo ""
echo "--- lambda usage ---"
grep -r "lambda" "$emacs_dir" --include="*.el" 2>/dev/null | wc -l

echo ""
echo "--- #' function reference ---"
grep -r "#'" "$emacs_dir" --include="*.el" 2>/dev/null | wc -l

echo ""
echo "--- cl-macrolet usage ---"
grep -r "cl-macrolet" "$emacs_dir" --include="*.el" 2>/dev/null | head -10

echo ""
echo "--- cl-labels usage ---"
grep -r "cl-labels" "$emacs_dir" --include="*.el" 2>/dev/null | head -10
