#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
docs_dir="$root/docs"

if [[ ! -d "$docs_dir" ]]; then
  echo "No docs/ directory, skipping link check" >&2
  exit 0
fi

missing=0
while IFS= read -r f; do
  while IFS= read -r line; do
    # very small heuristic: find markdown links [text](path)
    if [[ $line =~ \\[[^]]+\\]\(([^)]+)\\) ]]; then
      url="${BASH_REMATCH[1]}"
      # ignore http(s)
      if [[ $url =~ ^https?:// ]]; then
        continue
      fi
      # resolve relative path
      target="$root/$url"
      if [[ ! -e "$target" ]]; then
        echo "Broken doc link in $f: $url" >&2
        missing=$((missing+1))
      fi
    fi
  done < "$f"
done < <(find "$docs_dir" -type f -name "*.md")

if [[ $missing -gt 0 ]]; then
  echo "DOCS LINK-CHECK: $missing broken link(s)" >&2
  exit 2
fi

echo "DOCS LINK-CHECK: OK"
