#!/usr/bin/env bash
set -euo pipefail

# create-opencode-branch.sh <agent-id> <feature-slug>
# Создаёт ветку opencode/<agent-id>/<feature-slug>, добавляет шаблон метаданных
# и пушит ветку в origin.

agent=${1:-}
feature=${2:-work}

if [ -z "$agent" ]; then
  echo "Usage: $0 <agent-id> <feature-slug>" >&2
  exit 2
fi

branch="opencode/${agent}/${feature}"
worktree_dir="" # optional: if called from worktree, can be left empty

echo "Creating branch: ${branch}"

# create branch locally from current HEAD
git fetch origin --quiet
git checkout -b "${branch}" || git checkout "${branch}"

# ensure .opencode directory and template
mkdir -p .opencode
meta_template=".opencode/opencode-${agent}.json.template"
cat > "${meta_template}" <<EOF
{
  "agent_id": "${agent}",
  "branch": "${branch}",
  "created_by": "${USER:-unknown}",
  "created_at": "$(date -Iseconds)",
  "notes": "Fill .opencode/opencode-${agent}.json in your worktree (gitignored)."
}
EOF

# ensure .opencode/*.json is ignored
gitignore_entry=".opencode/opencode-${agent}.json"
if ! rg -x --silent -- "${gitignore_entry}" .gitignore 2>/dev/null; then
  echo "${gitignore_entry}" >> .gitignore
fi

# stage only template and .gitignore if not already tracked
git add -N "${meta_template}" .gitignore || true
git commit -m "chore(opencode): init opencode metadata template for ${agent}" "${meta_template}" .gitignore || true

echo "Pushing ${branch} to origin"
git push -u origin "${branch}"

echo "Created and pushed branch: ${branch}"
echo "Template: ${meta_template}"
exit 0
