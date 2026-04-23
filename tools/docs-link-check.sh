#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"

# Verbosity: env or flags (-v/--verbose/--debug)
dbg="${HDS_DOCS_LINK_DEBUG:-0}"
for arg in "${@:-}"; do
  case "$arg" in
    -v|--verbose|--debug) dbg="1";;
    *) :;;
  esac
done

# Collect Markdown-style links with file:line origin
# Example output line: path/to/file.md:12:docs/target.md
md_refs_docs="$(
  grep -REnH '\[[^]]*\]\(([^)#]+)\)' "$root/docs" 2>/dev/null \
    | sed -E 's/^([^:]+):([^:]+):.*\]\(([^)#]+)\).*/\1:\2:\3/'
)"
md_refs_root="$(
  grep -REnH '\[[^]]*\]\(([^)#]+)\)' "$root/README.md" "$root/HOLO.md" "$root/SURFACE.md" "$root/CONTRIBUTING.md" 2>/dev/null \
    | sed -E 's/^([^:]+):([^:]+):.*\]\(([^)#]+)\).*/\1:\2:\3/' || true
)"

# Collect Org-style links [[path]] or [[path][label]] with file:line origin
# We conservatively capture the first link per line.
org_refs_docs="$(
  grep -REnH '\[\[[^]]+\](\[[^]]*\])?\]' "$root/docs" 2>/dev/null \
    | sed -E 's/^([^:]+):([^:]+):.*\[\[([^]]+)\](\[[^]]*\])?\].*/\1:\2:\3/'
)"
org_refs_root="$(
  grep -REnH '\[\[[^]]+\](\[[^]]*\])?\]' "$root/README.md" "$root/HOLO.md" "$root/SURFACE.md" "$root/CONTRIBUTING.md" 2>/dev/null \
    | sed -E 's/^([^:]+):([^:]+):.*\[\[([^]]+)\](\[[^]]*\])?\].*/\1:\2:\3/' || true
)"

# Debug dump of raw references and stats
if [[ "$dbg" != "0" ]]; then
  echo "DOCS LINK-CHECK DEBUG: refs summary (counts)"
  echo "  md refs (docs):  $(printf "%s\n" "${md_refs_docs:-}" | sed '/^$/d' | wc -l | tr -d ' ')"
  echo "  md refs (root):  $(printf "%s\n" "${md_refs_root:-}" | sed '/^$/d' | wc -l | tr -d ' ')"
  echo "  org refs (docs): $(printf "%s\n" "${org_refs_docs:-}" | sed '/^$/d' | wc -l | tr -d ' ')"
  echo "  org refs (root): $(printf "%s\n" "${org_refs_root:-}" | sed '/^$/d' | wc -l | tr -d ' ')"
  echo "DOCS LINK-CHECK DEBUG: md refs (docs):"
  printf "%s\n" "${md_refs_docs:-}" | sed "s|^|  |"
  echo "DOCS LINK-CHECK DEBUG: md refs (root):"
  printf "%s\n" "${md_refs_root:-}" | sed "s|^|  |"
  echo "DOCS LINK-CHECK DEBUG: org refs (docs):"
  printf "%s\n" "${org_refs_docs:-}" | sed "s|^|  |"
  echo "DOCS LINK-CHECK DEBUG: org refs (root):"
  printf "%s\n" "${org_refs_root:-}" | sed "s|^|  |"
fi

missing=0

check_link() {
  local lnk="$1" origin="$2"
  # skip http(s), mailto, anchors
  [[ "$lnk" =~ ^https?:// ]] && return 0
  [[ "$lnk" =~ ^mailto: ]] && return 0
  [[ "$lnk" =~ ^# ]] && return 0
  # strip anchor if present
  lnk="${lnk%%#*}"
  # empty after stripping -> ok
  [[ -z "$lnk" ]] && return 0
  # try relative to docs/, then repo root
  if [[ -e "$root/docs/$lnk" || -e "$root/$lnk" ]]; then
    if [[ "$dbg" != "0" ]]; then
      echo "DOCS LINK-CHECK DEBUG: ok -> $lnk ($origin)"
    fi
    return 0
  else
    echo "DOCS LINK-CHECK: broken link -> $lnk (at $origin)" >&2
    missing=$((missing+1))
  fi
}

process_refs() {
  local refs="$1"
  while IFS= read -r rec; do
    [[ -z "$rec" ]] && continue
    # split rec into file:line:link
    local file="${rec%%:*}"
    local rest="${rec#*:}"
    local line="${rest%%:*}"
    local link="${rest#*:}"
    # Normalize origin relative to repo root
    local origin
    origin="$(realpath --relative-to="$root" "$file" 2>/dev/null || printf "%s" "$file"):$line"
    check_link "$link" "$origin"
  done <<< "$refs"
}

process_refs "$md_refs_docs"
process_refs "$md_refs_root"
process_refs "$org_refs_docs"
process_refs "$org_refs_root"

if [[ "$missing" -gt 0 ]]; then
  echo "DOCS LINK-CHECK: $missing broken link(s). Hint: set HDS_DOCS_LINK_DEBUG=1 or pass --debug for verbose diagnostics." >&2
  exit 1
fi

echo "DOCS LINK-CHECK: OK"
