#!/usr/bin/env bash
set -euo pipefail

# Deploy Emacs files from the repository into a user's ~/.config/emacs safely.
# Usage: scripts/deploy-emacs-from-repo.sh [target-user]
# If run as root, you may pass the target username or omit to use SUDO_USER.

USER_ARG=${1:-}
if [ -n "$USER_ARG" ]; then
  TARGET_USER=$USER_ARG
else
  if [ -n "${SUDO_USER-}" ]; then
    TARGET_USER=$SUDO_USER
  else
    TARGET_USER=$(id -un)
  fi
fi

TARGET_HOME=$(eval echo "~$TARGET_USER")
TARGET_DIR="$TARGET_HOME/.config/emacs"
REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

TIMESTAMP=$(date +%Y%m%d%H%M%S)

echo "Deploying pro-nix Emacs files to $TARGET_USER:$TARGET_DIR"

if [ -e "$TARGET_DIR" ]; then
  BACKUP="$TARGET_DIR.backup.$TIMESTAMP"
  echo "Backing up existing $TARGET_DIR -> $BACKUP"
  mv "$TARGET_DIR" "$BACKUP"
fi

mkdir -p "$TARGET_DIR"

# Use rsync for a safe copy that preserves mode bits; exclude runtime artifacts.
rsync -a --exclude='*.elc' --exclude='*.eln' --exclude='.cache' --exclude='.local' --exclude='*.backup.*' "$REPO_DIR/emacs/" "$TARGET_DIR/"

# If running as root, ensure ownership is set to target user.
if [ "$(id -u)" -eq 0 ]; then
  echo "Setting ownership of $TARGET_DIR to $TARGET_USER"
  chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_DIR"
fi

echo "Deployment complete. You can now test with: emacs --batch -l $TARGET_DIR/base/init.el --eval '(message \"emacs: deployed init loaded OK\")'"
exit 0
