#!/usr/bin/env bash
set -euo pipefail

# Headless test runner for pro-nix Emacs
# Runs tests in a disposable HOME environment without GUI

MODE="${1:-both}"
LOG_BASE="${EMACS_HEADLESS_TEST_DIR:-$PWD/logs/emacs-tests}"
STAMP="$(date +%Y%m%d-%H%M%S)"
RUN_DIR="$LOG_BASE/$STAMP"
RUN_HOME="$RUN_DIR/home"
MASTER_LOG="$RUN_DIR/run.log"
TTY_LOG="$RUN_DIR/tty.log"
XORG_LOG="$RUN_DIR/xorg.log"
EMACS_BIN="${EMACS_BIN:-emacs}"
REPO_DIR="${PRO_NIX_DIR:-$PWD}"
BASE_DIR="$REPO_DIR/emacs/base"
MODULES_DIR="$BASE_DIR/modules"

escape_path() {
  printf '%s' "$1" | sed 's/[\\&]/\\&/g'
}

mkdir -p "$RUN_DIR"
: > "$MASTER_LOG"
: > "$TTY_LOG"
: > "$XORG_LOG"
mkdir -p "$RUN_HOME/.config/emacs"
mkdir -p "$RUN_HOME/.config/emacs/modules"

exec > >(tee -a "$MASTER_LOG") 2>&1

hr() { printf '\n%s\n' '────────────────────────────────────────────────────────'; }
section() { hr; printf '%s\n' "$1"; hr; }
step() {
  local title="$1"; shift
  local logfile="$1"; shift
  section "$title"
  printf 'CMD: %s\n' "$*"
  { "$@"; } 2>&1 | tee -a "$logfile"
}

find_free_display() {
  local n
  for n in $(seq 99 120); do
    if [[ ! -e "/tmp/.X11-unix/X$n" ]]; then
      printf ':%s\n' "$n"
      return 0
    fi
  done
  return 1
}

run_tty() {
  section "TTY headless tests"
  local run_home_esc base_dir_esc modules_dir_esc
  run_home_esc="$(escape_path "$RUN_HOME")"
  base_dir_esc="$(escape_path "$BASE_DIR")"
  modules_dir_esc="$(escape_path "$MODULES_DIR")"

  local cmd
  # Do not explicitly load test files here: init.el / site-init are responsible
  # for loading modules and test helpers once. Explicitly loading tests from the
  # harness caused duplicate ERT definitions when site-init also loaded them.
  cmd="HOME=\"$RUN_HOME\" $EMACS_BIN --batch --quick \
    --eval \"(setq pro-test-repo-root \\\"$REPO_DIR\\\")\" \
    --eval \"(setq user-emacs-directory \\\"$run_home_esc/.config/emacs/\\\" pro-emacs-base-system-modules-dir nil pro-emacs-base-user-modules-dir \\\"$run_home_esc/.config/emacs/modules\\\" pro-emacs-base-user-manifest \\\"$run_home_esc/.config/emacs/modules.el\\\")\" \
    --load \"$base_dir_esc/init.el\" \
    --eval \"(ert-run-tests-batch-and-exit t)\""

  step "TTY ERT" "$TTY_LOG" bash -lc "$cmd"
}

run_xorg() {
  section "Xorg headless tests"
  if ! command -v Xvfb >/dev/null 2>&1; then
    printf 'Xvfb command is missing; add xorg.xorgserver to system packages.\n' | tee -a "$XORG_LOG"
    return 1
  fi

  local display
  display="$(find_free_display)"
  printf 'Using DISPLAY=%s\n' "$display" | tee -a "$XORG_LOG"

  Xvfb "$display" -screen 0 1280x720x24 -nolisten tcp >>"$XORG_LOG" 2>&1 &
  local xpid=$!
  trap 'kill "$xpid" >/dev/null 2>&1 || true' RETURN INT TERM
  sleep 1

  local run_home_esc base_dir_esc modules_dir_esc
  run_home_esc="$(escape_path "$RUN_HOME")"
  base_dir_esc="$(escape_path "$BASE_DIR")"
  modules_dir_esc="$(escape_path "$MODULES_DIR")"

  DISPLAY="$display" HOME="$RUN_HOME" "$EMACS_BIN" --batch --quick \
    --eval "(setq pro-test-repo-root \"$REPO_DIR\")" \
    --eval "(setq user-emacs-directory \"$run_home_esc/.config/emacs/\" pro-emacs-base-system-modules-dir nil pro-emacs-base-user-modules-dir \"$run_home_esc/.config/emacs/modules\" pro-emacs-base-user-manifest \"$run_home_esc/.config/emacs/modules.el\")" \
    --load "$base_dir_esc/init.el" \
    --eval "(ert-run-tests-batch-and-exit t)" \
    >>"$XORG_LOG" 2>&1

  kill "$xpid" >/dev/null 2>&1 || true
}

section " pro-nix Emacs Headless Test"
printf 'PWD: %s\n' "$PWD"
printf 'Repo dir: %s\n' "$REPO_DIR"
printf 'Log dir: %s\n' "$RUN_DIR"
printf 'Disposable HOME: %s\n' "$RUN_HOME"
printf 'Emacs: %s\n' "$EMACS_BIN"

case "$MODE" in
  tty) run_tty ;;
  xorg) run_xorg ;;
  both) run_tty; run_xorg ;;
  *)
    printf 'Usage: %s [tty|xorg|both]\n' "$0" >&2
    exit 2
    ;;
esac

section "Done"
printf 'Summary: %s\n' "$RUN_DIR"
printf '  run.log:  %s\n' "$MASTER_LOG"
printf '  tty.log:  %s\n' "$TTY_LOG"
printf '  xorg.log: %s\n' "$XORG_LOG"
