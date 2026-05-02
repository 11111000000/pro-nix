#!/usr/bin/env bash
set -euo pipefail

# Предложение: скрипт собирает изменённые файлы в рабочем дереве и генерирует
# черновой файл с предложениями обновить SURFACE.md / HOLO.md.
#
# Поведение:
# - По умолчанию только генерирует файл .changes/suggest-surface-<ts>.md
# - Опция --create-branch создаёт ветку suggest/surface-<ts> и коммитит файл
# - Ничего не вносит в SURFACE.md / HOLO.md автоматически
#
# Использование:
# ./scripts/suggest-surface-updates.sh [--create-branch]

OUTDIR=".changes"
mkdir -p "$OUTDIR"

ts=$(date -u +%Y%m%dT%H%M%SZ)
outfile="$OUTDIR/suggest-surface-$ts.md"

echo "# Предложения по обновлению SURFACE/HOLO — $ts" > "$outfile"
echo >> "$outfile"
echo "Автоматически сгенерированное черновое предложение. Требуется ручная проверка." >> "$outfile"
echo >> "$outfile"

# Собираем список изменённых файлов (staged, unstaged и untracked)
mapfile -t files < <(git status --porcelain=v1 --untracked-files=all | awk '{for (i=2;i<=NF;i++) printf $i " "; print ""}' | sed 's/ $//' | sed '/^$/d')

if [ ${#files[@]} -eq 0 ]; then
  echo "Нет изменений в дереве git. Ничего не предлагается." >> "$outfile"
  echo "Сгенерирован файл: $outfile"
  exit 0
fi

echo "Найдено ${#files[@]} изменённых файлов. Формирую предложения..."

for f in "${files[@]}"; do
  echo "---" >> "$outfile"
  echo "Файл: $f" >> "$outfile"
  echo >> "$outfile"
  echo "Intent: Предложить запись о влиянии изменения $f на публичную поверхность (SURFACE.md/HOLO.md)." >> "$outfile"
  echo "Pressure: Feature" >> "$outfile"
  echo "Surface impact: touches: $f [вручную проверить: FROZEN/FLUID]" >> "$outfile"
  echo "Proof: предложите команды/тесты для проверки (см. HOLO.md)." >> "$outfile"
  echo >> "$outfile"
  echo "Suggested entry (черновик):" >> "$outfile"
  echo >> "$outfile"
  echo "- Имя: [AUTO] $(basename "$f") change" >> "$outfile"
  echo "  Стабильность: [FLUID]" >> "$outfile"
  echo "  Спецификация: кратко опишите, какое поведение/опция затрагивается и почему это важно." >> "$outfile"
  echo "  Proof: добавьте соответствующие тесты/скрипты или укажите существующие команды для проверки." >> "$outfile"
  echo >> "$outfile"
done

echo "Файл с предложением создан: $outfile"

if [ "${1-}" = "--create-branch" ]; then
  branch="suggest/surface-$ts"
  echo "Создаю ветку $branch и коммитю $outfile"
  git checkout -b "$branch"
  git add "$outfile"
  git commit -m "chore(suggest): add suggested surface/HOLO updates for changes ($ts)"
  echo "Ветка $branch создана и закоммичена. Сделайте PR вручную и добавьте Change Gate/Proof перед мержем."
fi

exit 0
