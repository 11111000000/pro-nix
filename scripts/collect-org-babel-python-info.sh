#!/usr/bin/env bash
set -euo pipefail

out="${1:-}"
if [[ -n "${out}" ]]; then
  exec >"${out}" 2>&1
fi

section() {
  printf '\n\n===== %s =====\n' "$*"
}

run() {
  echo "+ $*"
  ( "$@" ) || echo "(!) command failed with exit=$?"
}

run_sh() {
  echo "+ $*"
  ( bash -lc "$*" ) || echo "(!) command failed with exit=$?"
}

show_python() {
  local exe="$1"
  section "Interpreter probe: ${exe}"
  if ! command -v "${exe}" >/dev/null 2>&1; then
    echo "not found in PATH"
    return 0
  fi

  local p
  p="$(command -v "${exe}")"
  echo "command -v ${exe} => ${p}"
  run readlink -f "${p}" || true
  run ls -l "${p}" || true

  # Show script head if it's a wrapper
  if [[ -f "${p}" ]]; then
    run_sh "head -n 60 \"${p}\""
  fi

  run_sh "${exe} -c 'import sys; print(\"executable=\", sys.executable); print(\"version=\", sys.version.replace(\"\\n\",\" \"))'"
  run_sh "${exe} -c 'import importlib.util as u; print(\"requests_spec=\", u.find_spec(\"requests\"))'"
  run_sh "${exe} -c 'import requests; print(\"requests_version=\", getattr(requests, \"__version__\", \"?\"))'"

  # Site / sys.path can help detect where packages are expected from
  run_sh "${exe} -c 'import sys; print(\"sys.path=\"); print(\"\\n\".join(sys.path))'"
}

section "Host / Nix / system info"
run uname -a
run_sh 'id'
run_sh 'echo "USER=$USER HOME=$HOME SHELL=$SHELL"'
run_sh 'echo "PWD=$PWD"'
run_sh 'nixos-version'
run_sh 'nix --version'
run_sh 'echo "PATH=$PATH"'

section "Where python binaries come from (common locations)"
run_sh 'ls -la /run/current-system/sw/bin/python* 2>/dev/null || true'
run_sh 'ls -la "/etc/profiles/per-user/$USER/bin/python*" 2>/dev/null || true'
run_sh 'ls -la "$HOME/.nix-profile/bin/python*" 2>/dev/null || true'
run_sh 'command -v python || true; command -v python3 || true; command -v python3.13 || true; command -v python3.12 || true; command -v python3.11 || true'
run_sh 'type -a python 2>/dev/null || true'
run_sh 'type -a python3 2>/dev/null || true'

show_python python
show_python python3
show_python python3.13
show_python python3.12
show_python python3.11

section "Emacs / org-babel related (if emacsclient daemon is running)"
run_sh 'command -v emacsclient || true'
run_sh 'systemctl --user is-active emacs.service 2>/dev/null || true'
run_sh 'systemctl --user status emacs.service --no-pager -l 2>/dev/null || true'
run_sh 'systemctl --user show emacs.service -p Environment -p ExecStart -p FragmentPath -p DropInPaths -p ActiveState -p SubState 2>/dev/null || true'
run_sh 'systemctl --user show-environment 2>/dev/null | sort || true'

# Try both default socket and the configured one (-s exwm). Non-fatal if not running.
run_sh 'emacsclient --version 2>/dev/null || true'
run_sh 'emacsclient -s exwm --eval "(list :emacs-version emacs-version :system-type system-type :exec-path exec-path :PATH (getenv \"PATH\") :python-shell-interpreter (and (boundp (quote python-shell-interpreter)) python-shell-interpreter) :org-babel-python-command (and (boundp (quote org-babel-python-command)) org-babel-python-command))" 2>/dev/null || true'

section "NixOS config quick grep (python wrappers / requests / org-babel hints)"
# Adjust if script is not executed from the nixos config dir
if [[ -f "./system-packages.nix" ]]; then
  run_sh 'grep -nE "myPython|withPackages|requests|pythonCmd|python3Cmd" -n ./system-packages.nix || true'
fi
if [[ -f "./systemd-user-services.nix" ]]; then
  run_sh 'grep -nE "PATH=|ExecStart|emacs" -n ./systemd-user-services.nix || true'
fi
if [[ -f "./configuration.nix" ]]; then
  run_sh 'grep -nE "environment\\.systemPackages|home\\.packages|python|requests|emacs" -n ./configuration.nix || true'
fi

section "Done"
echo "If you redirected output to a file, attach it. Otherwise copy-paste everything above."
