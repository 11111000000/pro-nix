#!/usr/bin/env bash
set -euo pipefail

# Moves agent-orchestration related files from this repo into ~/pro-agent
# and leaves a small placeholder note at the original location.

root="$(pwd)"
dest="$HOME/pro-agent"

files=(
  "nixos/modules/agents-model-client.nix"
  "nixos/modules/agents-control.nix"
  "nixos/modules/agents-retrieval.nix"
  "docs/plans/agent-orchestration.md"
  "docs/plans/agent-tooling.md"
  "docs/HOLO.md"
  "docs/SURFACE.md"
  "docs/analyse.md"
  "docs/system-reminder.md"
  "docs/pro-agents.md"
  "docs/operators/connect-pro-agent.md"
  "tests/contract/test_agent_secrets.sh"
  "tests/contract/test_agent_observability.sh"
  "docs/plabns/optimal-improvements-v2.md"
  "docs/plans/repo-agent-guide.md"
)

echo "Destination: $dest"
mkdir -p "$dest"

for f in "${files[@]}"; do
  if [ -e "$root/$f" ]; then
    echo "Moving $f -> $dest/$f"
    mkdir -p "$(dirname "$dest/$f")"
    mv "$root/$f" "$dest/$f"

    # leave placeholder
    mkdir -p "$(dirname "$root/$f")"
    cat > "$root/$f" <<EOF
This file has been moved to $dest/$f
It was part of the agent-orchestration surface and is now maintained in the separate project: $dest
EOF
  else
    echo "Not found: $f"
  fi
done

echo "Move complete. Please review changes and commit." 
