#!/usr/bin/env bash
# CI check: enforce agent conventions that should be mechanical, not prose.
# Each check encodes one rule from AGENTS.md as an executable assertion.

set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

exit_code=0

fail() {
    local rule="$1"; shift
    echo "❌ FAIL: $rule"
    echo "   $*"
    exit_code=1
}

# ── 1. Nix: no lib.mkDefault for required systemPackages ────────────────
echo "▸ Nix package priorities"
if grep -rn 'systemPackages.*=.*lib\.mkDefault' modules/*.nix 2>/dev/null | head -3; then
    fail "lib.mkDefault for systemPackages" \
         "Required packages must use plain assignment."
else
    echo "  ✅ no mkDefault for systemPackages"
fi

# ── 2. emacs-keys.org: 4 columns, valid commands ────────────────────────
echo "▸ emacs-keys.org format"
if [ -f "emacs-keys.org" ]; then
    # Data rows: starts with |, not separator (|---), not header (contains 'Секция')
    data=$(awk '/^\|/ && !/^\|[[:space:]]*-/ && !/Секция/' emacs-keys.org)
    total=$(echo "$data" | wc -l)

    # Each row has format: | col1 | col2 | col3 | col4 |
    # awk -F'|' on "|a|b|c|d|" yields 6 fields ($1="" $2=a $3=b $4=c $5=d $6="")
    bad_cols=$(echo "$data" | awk -F'|' 'NF != 6 { print NR": "$0 }' | head -3 || true)
    if [ -n "$bad_cols" ]; then
        fail "Column count: rows must have exactly 4 columns" "$bad_cols"
    else
        echo "  ✅ $total rows, correct columns"
    fi

    # Command field ($3 after trimming) must match: word-word/slash or word
    bad_cmds=$(echo "$data" | awk -F'|' '{gsub(/[ \t]/, "", $4); if ($4 != "" && $4 !~ /^[a-zA-Z][a-zA-Z0-9/_-]*$/) print NR": "$4}' | head -3 || true)
    if [ -n "$bad_cmds" ]; then
        fail "Invalid command names" "$bad_cmds"
    else
        echo "  ✅ command names valid"
    fi
else
    echo "  ⚠ SKIP: emacs-keys.org not found"
fi

# ── 3. Emacs modules: (provide 'name) at the end of every pro-*.el ─────
echo "▸ Emacs module provide"
missing=0
for f in emacs/base/modules/pro-*.el; do
    [ -f "$f" ] || continue
    feature=$(basename "$f" .el)
    if ! grep -q "(provide '$feature)" "$f"; then
        echo "  ❌ $f missing (provide '$feature)"
        ((missing++)) || true
    fi
done
if [ "$missing" -gt 0 ]; then
    fail "Missing provide" "$missing module(s) lack (provide 'name)"
else
    echo "  ✅ all modules have (provide '...)"
fi

# ── 4. Commit message format (last commit on HEAD) ──────────────────────
echo "▸ Commit message"
if [ -d .git ]; then
    msg=$(git log -1 --pretty=%s 2>/dev/null || true)
    if [ -n "$msg" ] && echo "$msg" | grep -qE '^[a-z][a-z_-]+:'; then
        echo "  ✅ $msg"
    else
        echo "  ⚠ warning: last commit may not match 'type: desc' format"
        echo "    $msg"
    fi
fi

echo ""
if [ "$exit_code" -eq 0 ]; then
    echo "✅ All agent conventions passed"
else
    echo "❌ Some checks failed (exit $exit_code)"
fi
exit $exit_code
