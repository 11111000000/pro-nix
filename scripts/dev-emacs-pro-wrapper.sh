#!/usr/bin/env bash
# Lightweight wrapper to run Emacs with -L flags for Nix-provided site-lisp dirs.
# It discovers package site-lisp directories in /nix/store by name and adds
# appropriate -L arguments so Emacs can `require` packages installed from Nix.

set -euo pipefail

PKGS=(
  vertico consult orderless marginalia gptel consult-dash consult-eglot consult-yasnippet
  corfu cape kind-icon avy expand-region yasnippet projectile treemacs vterm ace-window embark
)

LFLAGS=()
for p in "${PKGS[@]}"; do
  # match nix store items that contain the package name and have site-lisp
  for d in /nix/store/*-${p}-*/share/emacs/site-lisp /nix/store/*${p}*/share/emacs/site-lisp /nix/store/*-${p}*/share/emacs/site-lisp/elpa/*; do
    [ -d "$d" ] || continue
    LFLAGS+=("-L" "$d")
  done
done

EMACS_CMD="emacs"
if command -v emacs-pro >/dev/null 2>&1 && [ "$(basename "$0")" != "emacs-pro" ]; then
  # prefer emacs-pro if already available in PATH
  EMACS_CMD="emacs-pro"
fi

exec "$EMACS_CMD" -Q "${LFLAGS[@]}" "$@"
