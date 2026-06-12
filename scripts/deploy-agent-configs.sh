#!/usr/bin/env bash
set -euo pipefail

# Deploy local templates for pi and opencode into user config if missing.
# Usage: scripts/deploy-agent-configs.sh

TEMPLATES_DIR="$(dirname "$0")/../local-templates"
CONFIG_OPENCODE_DIR="$HOME/.config/opencode"
CONFIG_PI_DIR="$HOME/.pi/agent"
PROJECT_PI_DIR="$PWD/.pi"

mkdir -p "$CONFIG_OPENCODE_DIR"
mkdir -p "$CONFIG_PI_DIR"

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

echo "[deploy] Deploying OpenCode config..."
copy_if_missing "$TEMPLATES_DIR/opencode/opencode.json" "$CONFIG_OPENCODE_DIR/opencode.json"

echo "[deploy] Deploying global pi models/settings..."
copy_if_missing "$TEMPLATES_DIR/pi/models.json" "$CONFIG_PI_DIR/models.json"

echo "[deploy] Deploying project .pi (if missing)..."
if [ -d "$PROJECT_PI_DIR" ]; then
  echo "[deploy] project .pi already exists: $PROJECT_PI_DIR"
else
  mkdir -p "$PROJECT_PI_DIR"
  copy_if_missing "$TEMPLATES_DIR/pi/models.json" "$PROJECT_PI_DIR/models.json"
  copy_if_missing "$TEMPLATES_DIR/opencode/opencode.json" "$PROJECT_PI_DIR/opencode.json"
fi

echo "[deploy] Done. If you changed auth storage, ensure AITUNNEL_API_KEY is set (or use ~/.authinfo and pro-load-agent-env.sh)."
