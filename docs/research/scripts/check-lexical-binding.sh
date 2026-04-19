#!/usr/bin/env bash
# check-lexical-binding.sh
# Проверяет, какие файлы включают лексическую связанность

emacs_dir="/home/zoya/pro-nix/emacs"

echo "=== Проверка lexical-binding в файлах ==="
echo ""

grep -r "lexical-binding.*t" "$emacs_dir" --include="*.el" | while read -r line; do
    file=$(echo "$line" | cut -d: -f1)
    line_num=$(echo "$line" | cut -d: -f2)
    echo "✓ $file:$line_num"
done

echo ""
echo "=== Файлы БЕЗ lexical-binding ==="
echo ""

for f in $(find "$emacs_dir" -name "*.el" -type f); do
    if ! grep -q "lexical-binding.*t" "$f" 2>/dev/null; then
        echo "✗ $f"
    fi
done
