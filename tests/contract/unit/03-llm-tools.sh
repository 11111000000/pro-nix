#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../../.." && pwd)"

echo "03: llm tools checks"

if ! rg -n "llm-lab|jupyterlab|transformers|datasets|sentencepiece|tokenizers" "$root/modules/system-package-sets-dev.nix" >/dev/null 2>&1; then
  echo "missing llm research tooling references in system-package-sets-dev.nix" >&2
  exit 2
fi

echo "03: OK"
