#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-both}"
LOG_BASE="${EMACS_HEADLESS_LOG_DIR:-$PWD/logs/emacs-headless}"
STAMP="$(date +%Y%m%d-%H%M%S)"
RUN_DIR="$LOG_BASE/$STAMP"
RUN_HOME="$RUN_DIR/home"
MASTER_LOG="$RUN_DIR/run.log"
TTY_LOG="$RUN_DIR/tty.log"
XORG_LOG="$RUN_DIR/xorg.log"
# Prefer repository-provided emacs wrapper which includes Nix-provided -L paths
EMACS_BIN="${EMACS_BIN:-$PWD/.pro-emacs-wrapper/emacs-pro}"
# Fallback to system emacs if wrapper not present or not executable
if [ ! -x "$EMACS_BIN" ]; then
  EMACS_BIN="${EMACS_BIN:-emacs}"
fi
REPO_MODULES_DIR="${EMACS_MODULES_DIR:-$PWD/emacs/base/modules}"
REPO_BASE_DIR="${EMACS_BASE_DIR:-$PWD/emacs/base}"

escape_path() {
  printf '%s' "$1" | sed 's/[\\&]/\\&/g'
}

mkdir -p "$RUN_DIR"
: > "$MASTER_LOG"
: > "$TTY_LOG"
: > "$XORG_LOG"
mkdir -p "$RUN_HOME/.emacs.d"
mkdir -p "$RUN_HOME/.cache"

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
  section "TTY headless Emacs"
  if ! command -v script >/dev/null 2>&1; then
    printf 'script command is missing\n' | tee -a "$TTY_LOG"
    return 1
  fi

  local repo_modules_esc run_home_esc cmd
  repo_modules_esc="$(escape_path "$REPO_MODULES_DIR")"
  run_home_esc="$(escape_path "$RUN_HOME")"
  base_esc="$(escape_path "$REPO_BASE_DIR")"
  # Ensure the disposable HOME sees the repository's provided-packages and modules
  mkdir -p "$RUN_HOME/.config/emacs"
  # Generate a minimal provided-packages.el for the disposable run containing
  # only packages we want to assert as "provided" in this headless test.
  # Avoid copying the full repo file which may declare many packages not
  # available in the ephemeral environment and cause pro/packages-ensure to
  # error when a declared Nix package is missing at runtime.
  cat > "$RUN_HOME/.config/emacs/provided-packages.el" <<'EOF'
(setq pro-packages-provided-by-nix '(gptel agent-shell))

(provide 'provided-packages)
EOF

  # Ensure string quoting for Lisp literal paths
  cmd="HOME=\"$RUN_HOME\" $EMACS_BIN -nw --quick --eval \"(setq user-emacs-directory \\\"$run_home_esc/.emacs.d/\\\" pro-emacs-base-system-modules-dir \\\"$repo_modules_esc\\\" pro-emacs-base-user-modules-dir \\\"$run_home_esc/.emacs.d/modules\\\" pro-emacs-base-user-manifest \\\"$run_home_esc/.emacs.d/modules.el\\\")\" --load \"$base_esc/init.el\" --eval \"(setq pro-emacs-base-default-modules '(core ui text nav keys org lisp nix python c java haskell project git ai feeds chat agent exwm))\" --eval \"(message \\\"[pro-emacs] tty-ready\\\")\" --eval \"(kill-emacs 0)\""
  step "TTY bootstrap" "$TTY_LOG" script -qec "$cmd" /dev/null
}

run_xorg() {
  section "Xorg headless Emacs"
  if ! command -v Xvfb >/dev/null 2>&1; then
    printf 'Xvfb command is missing; add xorg.xorgserver to the system packages.\n' | tee -a "$XORG_LOG"
    return 1
  fi

  local display
  display="$(find_free_display)"
  printf 'Using DISPLAY=%s\n' "$display" | tee -a "$XORG_LOG"

  Xvfb "$display" -screen 0 1280x720x24 -nolisten tcp >>"$XORG_LOG" 2>&1 &
  local xpid=$!
  trap 'kill "$xpid" >/dev/null 2>&1 || true' RETURN INT TERM
  sleep 1

  local base_esc repo_modules_esc run_home_esc
  base_esc="$(escape_path "$REPO_BASE_DIR")"
  repo_modules_esc="$(escape_path "$REPO_MODULES_DIR")"
  run_home_esc="$(escape_path "$RUN_HOME")"
  DISPLAY="$display" HOME="$RUN_HOME" "$EMACS_BIN" --quick \
    --eval "(setq user-emacs-directory \"$run_home_esc/.emacs.d/\" pro-emacs-base-system-modules-dir \"$repo_modules_esc\" pro-emacs-base-user-modules-dir \"$run_home_esc/.emacs.d/modules\" pro-emacs-base-user-manifest \"$run_home_esc/.emacs.d/modules.el\")" \
    --load "$base_esc/init.el" \
    --eval "(setq pro-emacs-base-default-modules '(core ui text nav keys org lisp nix python c java haskell project git ai feeds chat agent exwm))" \
    --eval "(pro-emacs-base-start)" \
    --eval "(progn (message \"[pro-emacs] xorg-ready\") (when (display-graphic-p) (make-frame)) (kill-emacs 0))" \
    >>"$XORG_LOG" 2>&1
  kill "$xpid" >/dev/null 2>&1 || true
}

section "Context"
printf 'PWD: %s\n' "$PWD"
printf 'Log dir: %s\n' "$RUN_DIR"
printf 'Modules dir: %s\n' "$REPO_MODULES_DIR"
printf 'Disposable HOME: %s\n' "$RUN_HOME"
printf 'Emacs: %s\n' "$EMACS_BIN"

case "$MODE" in
  tty)
    run_tty
    ;;
  xorg)
    run_xorg
    ;;
  both)
    run_tty
    run_xorg
    ;;
  *)
    printf 'Usage: %s [tty|xorg|both]\n' "$0" >&2
    exit 2
    ;;
esac

section "Done"
printf 'TTY log:  %s\n' "$TTY_LOG"
printf 'Xorg log: %s\n' "$XORG_LOG"
printf 'Master:   %s\n' "$MASTER_LOG"
