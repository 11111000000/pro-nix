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

# Default include patterns (focused areas)
include_patterns=("*.nix" "modules/**" "nixos/**" "hosts/**" "flake.nix" "configuration.nix" "system-packages.nix")

# Default excludes
exclude_globs=("./.git/*" "docs/analyse/**" "logs/**" ".agent-shell/**" "vendor/**" "cache/**")

echo
echo "Searching for lib.mkForce usages in focused areas:" 
rg_args=(--hidden --no-ignore)
for g in "${exclude_globs[@]}"; do
  rg_args+=(--glob "!$g")
done
for p in "${include_patterns[@]}"; do
  rg -n "lib\.mkForce" "${rg_args[@]}" --glob "$p" || true
done
if rg -n "lib\.mkForce" "${rg_args[@]}" --glob "${include_patterns[0]}" >/dev/null 2>&1; then
  echo "WARNING: lib.mkForce usage detected in focused areas. Review these occurrences and ensure they are intentional." >&2
  found=1
fi

echo
echo "Counting environment.systemPackages declarations in focused areas:" 
count=$(rg -n "environment\.systemPackages" "${rg_args[@]}" --glob "{${include_patterns[*]}}" 2>/dev/null | wc -l || true)
echo "Found $count occurrences of environment.systemPackages (scoped)"
if [ "$count" -gt 5 ]; then
  echo "WARNING: multiple environment.systemPackages declarations (>5) in focused areas. Consider consolidating or using lib.mkDefault in modules." >&2
  found=1
fi

if [ "$found" -eq 1 ]; then
  echo
  echo "mkForce-lint: issues found (non-blocking). See warnings above."
else
  echo "mkForce-lint: no obvious issues detected in focused areas."
fi

# Keep non-blocking behavior for now (exit 0)
exit 0
