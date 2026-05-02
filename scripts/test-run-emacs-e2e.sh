#!/usr/bin/env bash
set -euo pipefail
OUTDIR=${OUTDIR:-/tmp/emacs-e2e-$(date +%Y%m%d%H%M%S)}
mkdir -p "$OUTDIR"
SCRIPT="$(dirname "$0")/emacs-e2e-test.el"

find_openssl34() {
  find /nix/store -maxdepth 2 -type d -name 'openssl-3.4*' 2>/dev/null | head -n1 || true
}

EMACS_BIN=${EMACS_BIN:-/run/current-system/sw/bin/emacs}
if [ ! -x "$EMACS_BIN" ]; then
  echo "emacs binary not found at $EMACS_BIN" >&2
  exit 3
fi

echo "Running clean start (-Q)"
if ! "$EMACS_BIN" --batch -Q -l "$SCRIPT" 2>&1 | tee "$OUTDIR/clean.log"; then
  echo "clean run failed, collecting strace"
  if command -v strace >/dev/null 2>&1; then
    strace -o "$OUTDIR/clean-strace.txt" "$EMACS_BIN" --batch -Q -l "$SCRIPT" || true
  fi
fi

echo "Running with user init (may reproduce failures)"
export EMACS_E2E_OUTDIR="$OUTDIR/with-init"
export EMACS_E2E_MODE="with-init"

OPENSSL_DIR=$(find_openssl34)
if [ -n "$OPENSSL_DIR" ]; then
  echo "Using $OPENSSL_DIR for LD_LIBRARY_PATH"
  LD_LIBRARY_PATH="$OPENSSL_DIR/lib" LD_PRELOAD="$OPENSSL_DIR/lib/libcrypto.so.3:$OPENSSL_DIR/lib/libssl.so.3" \
    "$EMACS_BIN" --batch -l "$SCRIPT" 2>&1 | tee "$OUTDIR/with-init.log" || true
else
  "$EMACS_BIN" --batch -l "$SCRIPT" 2>&1 | tee "$OUTDIR/with-init.log" || true
fi

tar -czf /tmp/emacs-e2e-results.tar.gz -C "$(dirname "$OUTDIR")" "$(basename "$OUTDIR")"
echo "Results: /tmp/emacs-e2e-results.tar.gz"
ls -lh /tmp/emacs-e2e-results.tar.gz
