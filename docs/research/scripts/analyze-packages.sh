# Русский: комментарии и пояснения оформлены в стиле учебника
#!/usr/bin/env bash
# analyze-packages.sh
# Анализирует способы загрузки пакетов в конфиге

emacs_dir="/home/zoya/pro-nix/emacs"

echo "=== Способы загрузки пакетов ==="
echo ""

echo "--- use-package usage ---"
grep -r "use-package" "$emacs_dir" --include="*.el" 2>/dev/null | head -20 || echo "use-package не найден"

echo ""
echo "--- require usage ---"
grep -r "require" "$emacs_dir" --include="*.el" 2>/dev/null | head -20

echo ""
echo "--- load usage ---"
grep -r "^\s*(load" "$emacs_dir" --include="*.el" 2>/dev/null | head -20

echo ""
echo "--- provide usage ---"
grep -r "provide" "$emacs_dir" --include="*.el" 2>/dev/null
