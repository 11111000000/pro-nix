#!/usr/bin/env bash
set -euo pipefail

host_profile="${1:-default}"

echo "Устанавливаем конфигурацию для: $host_profile"
# git+file://...?submodules=1 ensures Nix captures submodules into the store
# source. Local path: URLs and `.#name` shorthand do NOT include submodules,
# which breaks emacs-overlay recipes that read ../../submodules/<name>.
# See AGENTS.md §6c.
echo "Запуск: nixos-rebuild switch --flake \"git+file://$PWD?submodules=1#$host_profile\""
nixos-rebuild switch --flake "git+file://$PWD?submodules=1#$host_profile"
