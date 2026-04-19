#!/usr/bin/env bash
set -euo pipefail

target_dir="${1:-$HOME/.config/emacs}"
repo_root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"

if [ -e "$target_dir" ] || [ -L "$target_dir" ]; then
  backup_dir="${target_dir}.backup.$(date +%Y%m%d-%H%M%S)"
  mv "$target_dir" "$backup_dir"
  printf '%s\n' "Backed up existing Emacs tree to: $backup_dir"
fi

mkdir -p "$target_dir/modules"

cp -f "$repo_root/emacs/base/early-init.el" "$target_dir/early-init.el"
cp -f "$repo_root/emacs/base/init.el" "$target_dir/init.el"
cp -f "$repo_root/emacs/base/site-init.el" "$target_dir/site-init.el"
cp -R "$repo_root/emacs/base/modules/." "$target_dir/modules/"
cp -f "$repo_root/emacs-keys.org" "$target_dir/keys.org.example"

cat > "$target_dir/modules.el" <<'EOF'
;; Список модулей для портативного профиля.
(setq pro-emacs-modules '(core ui text nav keys org lisp nix python c java haskell project git ai feeds chat agent exwm))
EOF

if [ "$target_dir" = "$HOME/.config/emacs" ]; then
  legacy_dir="$HOME/.emacs.d"
  if [ -L "$legacy_dir" ] || [ -e "$legacy_dir" ]; then
    if [ "$(readlink -f "$legacy_dir")" != "$target_dir" ]; then
      legacy_backup_dir="${legacy_dir}.backup.$(date +%Y%m%d-%H%M%S)"
      mv "$legacy_dir" "$legacy_backup_dir"
      printf '%s\n' "Backed up legacy Emacs tree to: $legacy_backup_dir"
    fi
  fi
  ln -sfn "$target_dir" "$legacy_dir"
fi

printf '%s\n' "Synced portable Emacs into: $target_dir"
