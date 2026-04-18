#!/usr/bin/env bash
set -euo pipefail

host_profile="${1:-pro}"

echo "Устанавливаем конфигурацию для: $host_profile"
echo "Запуск: nixos-rebuild switch --flake .#$host_profile"
nixos-rebuild switch --flake ".#$host_profile"
