#!/usr/bin/env bash
# Создаёт git worktree для указанной ветки и возвращает путь. Простая обёртка для агентов.
set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 <branch> [<dest>]
Creates branch if missing and adds a worktree. If dest omitted, creates ../worktree-<branch>.
EOF
  exit 2
}

if [ $# -lt 1 ]; then
  usage
fi

branch=$1
dest=${2:-}

if [ -z "$dest" ]; then
  safe_branch=$(echo "$branch" | sed 's/[^a-zA-Z0-9._-]/-/g')
  dest="../worktree-${safe_branch}"
fi

# Ensure we are in repo root (where .git exists)
if [ ! -e .git ]; then
  echo "ERROR: .git not found in $(pwd). Run from repo root."
  exit 1
fi

# Create branch if it doesn't exist
if ! git rev-parse --verify "$branch" >/dev/null 2>&1; then
  echo "Branch '$branch' does not exist — creating from HEAD"
  git branch "$branch"
fi

echo "Adding worktree at $dest for branch $branch"
git worktree add "$dest" "$branch"
echo "Worktree created: $dest"
