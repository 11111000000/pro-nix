#!/usr/bin/env bash
# Проверяет, что текущая директория находится в linked worktree, а не в primary worktree.
set -euo pipefail

usage() {
  printf '%s\n' \
    "Использование: $0" \
    "Проверяет текущий git-контекст, а не каталог расположения скрипта." \
    "Работает из любой поддиректории git worktree." \
    "Код 0: linked worktree." \
    "Код 2: primary worktree." \
    "Код 1/3/4: некорректная среда или неожиданный формат."
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  printf 'ERROR: %s не находится внутри git worktree.\n' "$(pwd)" >&2
  exit 1
fi

root=$(git rev-parse --show-toplevel 2>/dev/null || true)
if [ -z "$root" ]; then
  printf 'ERROR: не удалось определить корень git worktree для %s.\n' "$(pwd)" >&2
  exit 1
fi

git_marker="$root/.git"

if [ -d "$git_marker" ]; then
  printf '%s\n' \
    "ERROR: обнаружен primary worktree ('.git' является директорией)." \
    "Агенты не правят primary worktree без явной команды юзера." \
    "Создайте отдельный linked worktree:" \
    "  cd $root && ./scripts/setup-worktree.sh <ветка> [<каталог>]" >&2
  exit 2
fi

if [ -f "$git_marker" ]; then
  first=$(sed -n '1p' "$git_marker")
  case "$first" in
    gitdir:*)
      printf 'OK: linked worktree (root: %s, gitdir: %s)\n' "$root" "${first#gitdir: }"
      exit 0
      ;;
    *)
      printf "ERROR: %s является файлом, но не содержит запись 'gitdir: ...'.\n" "$git_marker" >&2
      exit 3
      ;;
  esac
fi

printf 'ERROR: неизвестное состояние %s.\n' "$git_marker" >&2
exit 4
