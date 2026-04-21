# Русский: комментарии и пояснения оформлены в стиле учебника
#!/usr/bin/env bash
# search-modern-features.sh
# Поиск современных паттернов Emacs 30+

emacs_dir="/home/zoya/pro-nix/emacs"

echo "=== Поиск современных паттернов (Emacs 30.2+) ==="
echo ""

echo "--- eldoc-documentation-strategy ---"
grep -r "eldoc-documentation-strategy" "$emacs_dir" --include="*.el" 2>/dev/null | head -10 || echo "не найдено"

echo ""
echo "--- comp-deferred-compilation ---"
grep -r "comp-deferred-compilation" "$emacs_dir" --include="*.el" 2>/dev/null | head -10 || echo "не найдено"

echo ""
echo "--- compiler notes ---"
grep -r "comp-async-report-warnings-errors" "$emacs_dir" --include="*.el" 2>/dev/null | head -10 || echo "не найдено"

echo ""
echo "--- subword-mode ---"
grep -r "subword" "$emacs_dir" --include="*.el" 2>/dev/null | head -10 || echo "не найдено"

echo ""
echo "--- xref ---"
grep -r "xref" "$emacs_dir" --include="*.el" 2>/dev/null | head -10 || echo "не найдено"

echo ""
echo "--- newcomment ---"
grep -r "newcomment" "$emacs_dir" --include="*.el" 2>/dev/null | head -10 || echo "не найдено"

echo ""
echo "--- eldoc-box ---"
grep -r "eldoc-box" "$emacs_dir" --include="*.el" 2>/dev/null | head -10 || echo "не найдено"

echo ""
echo "--- corfu ---"
grep -r "corfu" "$emacs_dir" --include="*.el" 2>/dev/null | head -10 || echo "не найдено"

echo ""
echo "--- vertico ---"
grep -r "vertico" "$emacs_dir" --include="*.el" 2>/dev/null | head -10 || echo "не найдено"

echo ""
echo "--- marginalia ---"
grep -r "marginalia" "$emacs_dir" --include="*.el" 2>/dev/null | head -10 || echo "не найдено"

echo ""
echo "--- orderless ---"
grep -r "orderless" "$emacs_dir" --include="*.el" 2>/dev/null | head -10 || echo "не найдено"

echo ""
echo "--- consult ---"
grep -r "consult" "$emacs_dir" --include="*.el" 2>/dev/null | head -10 || echo "не найдено"
