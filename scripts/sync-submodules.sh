#!/usr/bin/env bash
# scripts/sync-submodules.sh — обновить все submodules с remote main/master.
#
# Автономная версия логики из scripts/helper-switch.sh (старый блок
# `[simple-helper] Updating submodules...`), вынесенная в отдельный скрипт
# для двух целей:
#   1) `just sync-submodules` — обновить submodules без последующего switch.
#   2) `just switch ... update-submodules` — вызывается из helper-switch.sh,
#      если передан флаг (см. там же case update).
#
# Поведение:
#   - sequential fetch (timeout 20s) + merge (timeout 10s) на каждый submodule.
#   - 8 параллельных воркеров по умолчанию упираются в github/codeberg rate-limit
#     и висят 60+ секунд; 1×submodule × ~15s = ~165s worst case, приемлемо.
#   - Параллельный fetch не используется, чтобы не нарываться на лимиты.
#   - При сбое fetch/merge — WARNING, submodule остаётся на локальном HEAD.
#     Nix-рецепты читают ЛОКАЛЬНЫЙ submodules/<name>, а не remote, поэтому
#     прошлый валидный commit/submodule-pair остаётся годным для сборки.
#
# Использование:
#   just sync-submodules
#   # или напрямую:
#   ./scripts/sync-submodules.sh

set -euo pipefail

# Если в каком-то submodule есть локальные изменения — падаем громко,
# чтобы случайно не затоптать работу пользователя.
dirty=$(git submodule foreach --quiet 'git diff --quiet HEAD -- || echo $sm_name' 2>/dev/null | sed '/^$/d')
if [ -n "$dirty" ]; then
  echo "[sync-submodules] ERROR: submodules have uncommitted changes:" >&2
  echo "$dirty" | sed 's/^/  - /' >&2
  echo "[sync-submodules] Commit/stash them or run with PRO_NIX_NO_SUBMODULE_UPDATE=1 (not applicable here, this script is for explicit sync)" >&2
  exit 1
fi

# GIT_TERMINAL_PROMPT=0 — не висеть на запросе credentials для HTTPS-сабмодулей,
# у которых нет credential helper.
export GIT_TERMINAL_PROMPT=0

echo "[sync-submodules] Updating submodules (sequential, 20s fetch + 10s merge each)..."
failed_subs=()
updated_count=0
for sub in $(git submodule foreach -q 'echo $sm_path'); do
  name=$(basename "$sub")
  # 1) fetch с timeout (подавляем вывод fetch — он шумный, логируем только статус)
  if ! timeout 20 git -C "$sub" fetch origin >/dev/null 2>&1; then
    echo "[sync-submodules] WARNING: $name fetch failed/timeout — using local HEAD" >&2
    failed_subs+=("$name")
    continue
  fi
  # 2) merge в локальный HEAD с timeout.
  # `git submodule update --remote <path>` мержит remote-tracking branch
  # в локальный HEAD. Если merge не нужен (уже на свежем коммите) — exit 0 за <1с.
  if ! timeout 10 git submodule update --remote "$sub" 2>&1 \
       | sed "s/^/[sync-submodules] submod[$name]: /"; then
    echo "[sync-submodules] WARNING: $name merge failed/timeout — using local HEAD" >&2
    failed_subs+=("$name")
    continue
  fi
  updated_count=$((updated_count + 1))
done

if [ "${#failed_subs[@]}" -gt 0 ]; then
  echo "[sync-submodules] These submodules were NOT updated (kept local HEAD):" >&2
  printf '  - %s\n' "${failed_subs[@]}" >&2
  echo "[sync-submodules] Common causes: codeberg/github rate-limit, network timeout." >&2
fi
echo "[sync-submodules] Done: $updated_count updated, ${#failed_subs[@]} skipped."
