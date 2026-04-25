# Название: tools/mkforce-lint.sh — Проверка опасных использований lib.mkForce
# Summary (EN): Lint for dangerous lib.mkForce and systemPackages usage
# Цель:
#   Сканировать репозиторий и выявлять потенциально опасные использования
#   lib.mkForce и множественные определения environment.systemPackages.
# Контракт:
#   Опции: нет (скрипт принимает аргументы)
#   Побочные эффекты: выводит предупреждения в stderr.
# Предпосылки:
#   Требуется ripgrep (rg).
# Как проверить (Proof):
#   `./tools/mkforce-lint.sh`
# Last reviewed: 2026-04-25
#!/usr/bin/env bash
set -euo pipefail

# Non-blocking lint: detect potentially dangerous uses of lib.mkForce and
# multiple definitions of environment.systemPackages.
root="$(cd "$(dirname "$0")/.." && pwd)"

echo "mkForce-lint: scanning repository for lib.mkForce and environment.systemPackages"
found=0

echo
echo "Searching for lib.mkForce usages:" 
rg -n "lib\.mkForce" --hidden --no-ignore --glob '!./.git/*' || true
if rg -n "lib\.mkForce" --hidden --no-ignore --glob '!./.git/*' >/dev/null 2>&1; then
  echo "WARNING: lib.mkForce usage detected. Review these occurrences and ensure they are intentional." >&2
  found=1
fi

echo
echo "Counting environment.systemPackages declarations:" 
count=$(rg -n "environment\.systemPackages" --hidden --no-ignore --glob '!./.git/*' | wc -l || true)
echo "Found $count occurrences of environment.systemPackages"
if [ "$count" -gt 5 ]; then
  echo "WARNING: multiple environment.systemPackages declarations (>5). Consider consolidating or using lib.mkDefault in modules." >&2
  found=1
fi

if [ "$found" -eq 1 ]; then
  echo
  echo "mkForce-lint: issues found (non-blocking). See warnings above."
else
  echo "mkForce-lint: no obvious issues detected."
fi

# Always exit 0 to be non-blocking initially
exit 0
