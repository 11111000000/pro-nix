#!/usr/bin/env bash
# simple-helper-switch — предварительная проверка перед switch
#
# Использует nixpkgs defaults напрямую (без кастомных модулей).
# Предлагает использовать boot для избежания race conditions при switch.

HOST_ARG="${1:-}"
HOST_ARG="${HOST_ARG#HOST=}"
FLAKE_REF="path:$PWD"

if [ -z "$HOST_ARG" ]; then
  if [ -r /etc/hostname ]; then
    HOST_ARG=$(</etc/hostname)
  elif command -v hostname >/dev/null 2>&1; then
    HOST_ARG=$(hostname -s 2>/dev/null || hostname 2>/dev/null || true)
  fi
fi

if [ -z "$HOST_ARG" ]; then
  echo "No hostname detected." >&2
  exit 1
fi

if [ ! -f "./hosts/$HOST_ARG/configuration.nix" ]; then
  echo "No config: ./hosts/$HOST_ARG/configuration.nix" >&2
  exit 1
fi

echo "[simple-helper] Checking configuration for host: $HOST_ARG"

# 1. Preflight eval — проверяем что конфигурация вычисляется.
# Явный path:-ref не заставляет root открывать рабочее дерево как Git-репозиторий.
echo "[simple-helper] Running preflight eval..."
if ! nix --extra-experimental-features 'nix-command flakes' eval --json "$FLAKE_REF#nixosConfigurations.$HOST_ARG.config.environment.systemPackages" >/dev/null 2>&1; then
  echo "[simple-helper] ERROR: preflight eval failed" >&2
  exit 1
fi

echo "[simple-helper] Preflight eval passed."

# 2. Запуск switch с сохранением логов
echo ""
echo "[simple-helper] Running switch for $HOST_ARG..."
SWITCH_LOG="/tmp/switch-$(date +%s).log"
echo "[simple-helper] Logs will be saved to $SWITCH_LOG"

sudo nixos-rebuild switch --flake "$FLAKE_REF#$HOST_ARG" 2>&1 | tee "$SWITCH_LOG"

echo ""
echo "=== Рекомендуемый способ активации ==="
echo ""
echo "# Вариант 1: boot (безопасно, активируется при reboot)"
echo "  sudo nixos-rebuild boot --flake '$FLAKE_REF#$HOST_ARG'"
echo "  sudo reboot"
echo ""
echo "# Вариант 2: switch (риск race condition, но быстрее)"
echo "  sudo nixos-rebuild switch --flake '$FLAKE_REF#$HOST_ARG'"
echo ""
echo "Выберите способ и выполните вручную."
