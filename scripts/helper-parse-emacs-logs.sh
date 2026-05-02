#!/usr/bin/env bash
set -euo pipefail

LOG_PATH="${1:-${EMACS_HEADLESS_LOG_DIR:-$PWD/logs/emacs-headless}}"

latest_run() {
  if [[ -d "$LOG_PATH" ]]; then
    ls -1td "$LOG_PATH"/*/ 2>/dev/null | head -1
  else
    dirname "$LOG_PATH"
  fi
}

show_file() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  printf '\n%s\n' "== $(basename "$file") =="
  grep -E '\[test\]|\[pro-emacs\]|ERT|passed|FAILED|error|ERROR|FAIL' "$file" 2>/dev/null || true
}

run_dir="$(latest_run)"
if [[ -z "$run_dir" ]]; then
  printf 'No logs found in %s\n' "$LOG_PATH" >&2
  exit 1
fi

printf 'Run: %s\n' "$run_dir"
show_file "$run_dir/run.log"
show_file "$run_dir/tty.log"
show_file "$run_dir/xorg.log"
