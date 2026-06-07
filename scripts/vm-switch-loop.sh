#!/usr/bin/env bash
# vm-switch-loop.sh — логируемый VM-цикл для проверки DBus regression.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG_DIR="$ROOT/logs/diagnostics/vm-switch-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$LOG_DIR"

export PATH="/run/current-system/sw/bin:/run/wrappers/bin:$PATH"

CHECK="git+file://$ROOT?submodules=1#checks.x86_64-linux.cf19-switch-dbus-regression"

log_status() {
  printf '%s\n' "$1" | tee -a "$LOG_DIR/status.log"
}

: > "$LOG_DIR/status.log"
log_status "[start] $(date -Is)"
log_status "[check] $CHECK"
log_status "[cmd] nix build --refresh -L $CHECK --print-out-paths"

if OUT_PATH="$(nix build --refresh -L "$CHECK" --print-out-paths 2>&1 | tee "$LOG_DIR/build.log" | tail -n 1)"; then
  log_status "[out] $OUT_PATH"
else
  log_status "[fail] VM regression build failed"
  exit 1
fi

log_status "[cmd] nix log $OUT_PATH"
if nix log "$OUT_PATH" 2>&1 | tee "$LOG_DIR/runtime.log"; then
  log_status "[ok] VM runtime log captured"
else
  log_status "[fail] cannot read VM runtime log"
  exit 1
fi

if grep -q 'Rejected send message' "$LOG_DIR/runtime.log"; then
  log_status "[fail] DBus rejected-message cascade found"
  exit 1
fi

if grep -q 'Error: Failed to list systemd units' "$LOG_DIR/runtime.log"; then
  log_status "[fail] systemd unit listing failure found"
  exit 1
fi

if grep -q 'CF19 DBUS SWITCH REGRESSION TEST PASSED' "$LOG_DIR/runtime.log"; then
  log_status "[ok] VM regression marker found"
else
  log_status "[fail] VM regression marker not found"
  exit 1
fi

log_status "[done] $(date -Is)"
log_status "[logs] $LOG_DIR"
