#!/usr/bin/env bash
# Проверяет, что текущая директория является git worktree (не primary worktree).
# Выход 0 — если OK, 1 — если нет.
set -euo pipefail

here=$(pwd)

# .git может быть либо директория (primary worktree), либо файл с gitdir: <path-to-gitdir>
if [ ! -e .git ]; then
  echo "ERROR: .git not found in $(pwd) — не репозиторий git?"
  exit 1
fi

if [ -d .git ]; then
  echo "ERROR: Похоже вы в primary worktree ('.git' — директория). Используйте git worktree."
  echo "Run: ./scripts/setup-worktree.sh <branch> to create a worktree."
  exit 2
fi

if [ -f .git ]; then
  first=$(head -n1 .git || true)
  case "$first" in
    gitdir:*)
      echo "OK: this is a git worktree (gitdir -> ${first#gitdir: })"
      exit 0
      ;;
    *)
      echo "WARNING: .git is a file but not 'gitdir: ...' — unexpected format"
      exit 3
      ;;
  esac
fi

echo "Unknown state"
exit 4
