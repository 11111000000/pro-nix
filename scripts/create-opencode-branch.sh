#!/usr/bin/env bash
set -euo pipefail

# create-opencode-branch.sh <agent-id> <feature-slug> [<dest>]
# Создаёт linked worktree для ветки opencode/<agent-id>/<feature-slug>,
# добавляет шаблон метаданных и пушит ветку в origin.

usage() {
  printf '%s\n' \
    "Использование: $0 <agent-id> <feature-slug> [<каталог>]" \
    "Создаёт ветку opencode/<agent-id>/<feature-slug> в отдельном linked worktree." \
    "Если каталог не указан, используется ../worktree-opencode-<agent-id>-<feature-slug>."
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

agent=${1:-}
feature=${2:-work}
dest=${3:-}

if [ -z "$agent" ]; then
  usage >&2
  exit 2
fi

branch="opencode/${agent}/${feature}"

if [ -z "$dest" ]; then
  dest="../worktree-opencode-${agent}-${feature}"
fi

printf 'Подготавливаю ветку %s\n' "$branch"
git fetch origin --quiet || true
./scripts/setup-worktree.sh "$branch" "$dest"

meta_template="$dest/.opencode/opencode-${agent}.json.template"
meta_template_rel=".opencode/opencode-${agent}.json.template"
gitignore_entry=".opencode/opencode-${agent}.json"

mkdir -p "$dest/.opencode"
cat > "$meta_template" <<EOF
{
  "agent_id": "${agent}",
  "branch": "${branch}",
  "created_by": "${USER:-unknown}",
  "created_at": "$(date -Iseconds)",
  "notes": "Заполните .opencode/opencode-${agent}.json локально в linked worktree; файл не коммитится."
}
EOF

if ! rg -x --silent -- "$gitignore_entry" "$dest/.gitignore" 2>/dev/null; then
  printf '%s\n' "$gitignore_entry" >> "$dest/.gitignore"
fi

git -C "$dest" add "$meta_template_rel" .gitignore
git -C "$dest" commit -m "chore(opencode): init metadata template for ${agent}" || true
git -C "$dest" push -u origin "$branch"

printf 'Ветка создана и опубликована: %s\n' "$branch"
printf 'Рабочий каталог: %s\n' "$dest"
printf 'Шаблон: %s\n' "$meta_template"
