#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../../.." && pwd)"

echo "03: llm tools checks"

if ! rg -n "llm-lab|jupyterlab|transformers|datasets|sentencepiece|tokenizers" "$root/system-packages.nix" >/dev/null 2>&1; then
  echo "missing llm research tooling references in system-packages.nix" >&2
  exit 2
fi

if ! rg -n "goose|aider|opencode|llm-lab" "$root/system-packages.nix" >/dev/null 2>&1; then
  echo "tool matrix incomplete in system-packages.nix" >&2
  exit 3
fi

echo "03: OK"
