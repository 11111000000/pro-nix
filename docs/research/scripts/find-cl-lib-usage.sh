# Русский: комментарии и пояснения оформлены в стиле учебника
#!/usr/bin/env bash
# find-cl-lib-usage.sh
# Ищет использование cl-lib в конфиге

emacs_dir="/home/zoya/pro-nix/emacs"

echo "=== Анализ cl-lib usage ==="
echo ""

echo "--- cl-lib require ---"
grep -r "require.*cl-lib" "$emacs_dir" --include="*.el" 2>/dev/null || echo "cl-lib не найден в require"

echo ""
echo "--- cl- functions/macros ---"
grep -r "cl-" "$emacs_dir" --include="*.el" 2>/dev/null | grep -E "(cl-|cl-)" | head -30

echo ""
echo "--- pcase usage ---"
grep -r "pcase" "$emacs_dir" --include="*.el" 2>/dev/null | wc -l
grep -r "pcase" "$emacs_dir" --include="*.el" 2>/dev/null | head -10

echo ""
echo "--- with-let usage ---"
grep -r "with-let" "$emacs_dir" --include="*.el" 2>/dev/null | head -10 || echo "не найдено"

echo ""
echo "--- use-setq usage ---"
grep -r "use-setq" "$emacs_dir" --include="*.el" 2>/dev/null | head -10 || echo "не найдено"
