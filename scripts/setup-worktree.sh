#!/usr/bin/env bash
# Создаёт linked worktree для указанной ветки. Если ветки нет, создаёт её от HEAD.
set -euo pipefail

usage() {
  printf '%s\n' \
    "Использование: $0 <ветка> [<каталог>]" \
    "Создаёт linked worktree для указанной ветки." \
    "Если ветка отсутствует, она создаётся от текущего HEAD." \
    "Если каталог не указан, используется ../worktree-<ветка>."
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

if [ $# -lt 1 ]; then
  usage >&2
  exit 2
fi

branch=$1
dest=${2:-}

if [ ! -e .git ]; then
  printf 'ERROR: .git не найден в %s. Запустите скрипт из корня репозитория.\n' "$(pwd)" >&2
  exit 1
fi

if [ -z "$dest" ]; then
  safe_branch=$(printf '%s' "$branch" | tr '/:' '--' | tr -c '[:alnum:]._-' '-')
  dest="../worktree-${safe_branch}"
fi

if [ -e "$dest" ]; then
  printf 'ERROR: каталог уже существует: %s\n' "$dest" >&2
  exit 3
fi

if git show-ref --verify --quiet "refs/heads/$branch"; then
  printf 'Добавляю worktree %s для существующей ветки %s\n' "$dest" "$branch"
  git worktree add "$dest" "$branch"
else
  printf 'Создаю ветку %s от HEAD и добавляю worktree %s\n' "$branch" "$dest"
  git worktree add -b "$branch" "$dest"
fi

printf 'Worktree создан: %s\n' "$dest"
