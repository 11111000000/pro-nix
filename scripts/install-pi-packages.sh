#!/usr/bin/env bash
set -euo pipefail

# Install pi npm-extension packages declared in local-templates/pi/settings.json.
# Usage: scripts/install-pi-packages.sh [--dry-run]
#
# Idempotent: pi install npm:... is a no-op for already-installed packages
# (it only updates settings.json), so this script is safe to run multiple
# times. It uses the *deployed* settings.json at ~/.pi/agent/settings.json,
# not the template — that's what the user actually has.
#
# See docs/agent-configs.md for the full architecture.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE_SETTINGS="$SCRIPT_DIR/../local-templates/pi/settings.json"
USER_SETTINGS="$HOME/.pi/agent/settings.json"
PI_BIN="$(command -v pi || true)"

DRY_RUN=0
if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN=1
  shift
fi

log(){ printf '[install-pi-packages] %s\n' "$*"; }
err(){ printf '[install-pi-packages] ERROR: %s\n' "$*" >&2; }

# 1. Sanity checks.
if [ -z "$PI_BIN" ]; then
  err "pi binary not found in PATH. Install pi (npm i -g @mariozechner/pi-coding-agent) first."
  exit 1
fi

if [ ! -r "$TEMPLATE_SETTINGS" ]; then
  err "template not found: $TEMPLATE_SETTINGS"
  exit 1
fi

# 2. Extract the packages array from the *deployed* settings.json if present,
#    otherwise fall back to the template. We read what the user actually has
#    so re-running this script respects locally added/removed packages.
PACKAGES_SRC="$USER_SETTINGS"
if [ ! -r "$PACKAGES_SRC" ]; then
  log "no deployed settings.json at $USER_SETTINGS; reading template instead"
  PACKAGES_SRC="$TEMPLATE_SETTINGS"
fi

# Use python3 for reliable JSON parsing (jq may not be installed).
mapfile -t PACKAGES < <(python3 - "$PACKAGES_SRC" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    cfg = json.load(f)
pkgs = cfg.get("packages") or []
for p in pkgs:
    if not isinstance(p, str) or not p.startswith("npm:"):
        print(f"WARN: skipping non-npm entry: {p!r}", file=sys.stderr)
        continue
    print(p)
PY
)

if [ "${#PACKAGES[@]}" -eq 0 ]; then
  log "no npm: packages declared in $PACKAGES_SRC — nothing to do."
  exit 0
fi

log "installing ${#PACKAGES[@]} package(s) via 'pi install':"
for p in "${PACKAGES[@]}"; do
  log "  - $p"
done

# 3. pi install takes one source at a time, so loop. Each call is idempotent:
#    for an already-installed package pi just updates settings.json.
if [ "$DRY_RUN" -eq 1 ]; then
  log "(dry-run) would run, for each:"
  for p in "${PACKAGES[@]}"; do
    log "  $PI_BIN install $p"
  done
  exit 0
fi

FAILED=()
for p in "${PACKAGES[@]}"; do
  log "installing $p ..."
  if ! "$PI_BIN" install "$p"; then
    FAILED+=("$p")
  fi
done

if [ "${#FAILED[@]}" -gt 0 ]; then
  err "failed to install: ${FAILED[*]}"
  exit 1
fi

log "done. Run 'pi list' to verify."
