#!/usr/bin/env bash
set -euo pipefail

# Deploy local templates for pi and opencode into user config if missing.
# Usage: scripts/deploy-agent-configs.sh
#
# This script mirrors the home-manager activation in
# `modules/pro-agent-configs.nix` (pro.agent-configs.templateFiles). It is
# called by `just switch-with-agents` so the templates are in place even when
# home-manager activation is skipped (e.g. on non-NixOS hosts, or when the
# user runs this script standalone). It is idempotent: existing files are
# not overwritten.

TEMPLATES_DIR="$(cd "$(dirname "$0")/.." && pwd)/local-templates"
CONFIG_OPENCODE_DIR="$HOME/.config/opencode"
CONFIG_PI_DIR="$HOME/.pi/agent"
CONFIG_KIMI_CODE_DIR="$HOME/.kimi-code"
PROJECT_PI_DIR="$PWD/.pi"

mkdir -p "$CONFIG_OPENCODE_DIR"
mkdir -p "$CONFIG_PI_DIR"
mkdir -p "$CONFIG_KIMI_CODE_DIR"

copy_if_missing(){
  local src="$1" dst="$2"
  if [ -e "$dst" ]; then
    echo "[deploy] exists: $dst"
  else
    echo "[deploy] copying $src -> $dst"
    mkdir -p "$(dirname "$dst")"
    cp -a "$src" "$dst"
  fi
}

# Copy every regular file under $src_dir into $dst_dir, preserving relative
# paths but never overwriting existing files. Empty directories in $src_dir
# are not created in $dst_dir (skill discovery is by-file, not by-empty-dir).
copy_tree_if_missing(){
  local src_dir="$1" dst_dir="$2"
  if [ ! -d "$src_dir" ]; then
    return 0
  fi
  mkdir -p "$dst_dir"
  # Use find with -exec so $src_dir is embedded in the destination path by
  # simple shell substitution — that avoids any glob/path mangling from
  # variable expansion in pipes.
  find "$src_dir" -type f | while read -r src_file; do
    local rel="${src_file#"$src_dir"/}"
    copy_if_missing "$src_file" "$dst_dir/$rel"
  done
}

# --- OpenCode (user-global) ---
echo "[deploy] Deploying OpenCode config..."
copy_if_missing "$TEMPLATES_DIR/opencode/opencode.json" "$CONFIG_OPENCODE_DIR/opencode.json"
copy_tree_if_missing "$TEMPLATES_DIR/opencode/skills"   "$CONFIG_OPENCODE_DIR/skills"

# --- pi (user-global) ---
echo "[deploy] Deploying global pi configs..."
copy_if_missing "$TEMPLATES_DIR/pi/models.json"   "$CONFIG_PI_DIR/models.json"
copy_if_missing "$TEMPLATES_DIR/pi/mcp.json"      "$CONFIG_PI_DIR/mcp.json"
copy_if_missing "$TEMPLATES_DIR/pi/settings.json" "$CONFIG_PI_DIR/settings.json"
copy_tree_if_missing "$TEMPLATES_DIR/pi/skills"    "$CONFIG_PI_DIR/skills"

# --- Kimi Code CLI (user-global) ---
echo "[deploy] Deploying Kimi Code CLI config..."
copy_if_missing "$TEMPLATES_DIR/kimi-code/mcp.json" "$CONFIG_KIMI_CODE_DIR/mcp.json"

# --- Project-local .pi (only if .pi does not yet exist) ---
echo "[deploy] Deploying project .pi (if missing)..."
if [ -d "$PROJECT_PI_DIR" ]; then
  echo "[deploy] project .pi already exists: $PROJECT_PI_DIR"
else
  mkdir -p "$PROJECT_PI_DIR"
  copy_if_missing "$TEMPLATES_DIR/pi/models.json"             "$PROJECT_PI_DIR/models.json"
  copy_if_missing "$TEMPLATES_DIR/opencode/opencode.json"     "$PROJECT_PI_DIR/opencode.json"
fi

echo "[deploy] Done. If you changed auth storage, ensure AITUNNEL_API_KEY is set (or use ~/.authinfo and pro-load-agent-env.sh)."
