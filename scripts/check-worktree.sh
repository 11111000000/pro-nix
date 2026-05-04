#!/usr/bin/env bash
# Проверяет, что текущая директория является linked worktree, а не primary worktree.
set -euo pipefail

usage() {
  printf '%s\n' \
    "Использование: $0" \
    "Проверяет, что текущая директория является linked worktree Git." \
    "Код 0: linked worktree." \
    "Код 2: primary worktree." \
    "Код 1/3/4: некорректная среда или неожиданный формат."
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

if [ ! -e .git ]; then
  printf 'ERROR: .git не найден в %s — это не корень git-рабочего дерева.\n' "$(pwd)" >&2
  exit 1
fi

if [ -d .git ]; then
  printf '%s\n' \
    "ERROR: обнаружен primary worktree ('.git' является директорией)." \
    "Создайте отдельный linked worktree: ./scripts/setup-worktree.sh <ветка> [<каталог>]" >&2
  exit 2
fi

if [ -f .git ]; then
  first=$(sed -n '1p' .git)
  case "$first" in
    gitdir:*)
      printf 'OK: linked worktree (%s)\n' "${first#gitdir: }"
      exit 0
      ;;
    *)
      printf "ERROR: .git является файлом, но не содержит запись 'gitdir: ...'.\n" >&2
      exit 3
      ;;
  esac
fi

printf 'ERROR: неизвестное состояние .git.\n' >&2
exit 4
