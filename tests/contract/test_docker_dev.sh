#!/usr/bin/env bash
set -euo pipefail

# Contract test: docker-утилиты доступны на всех 4 хостах.
# Проверяет:
#   1. virtualisation.docker.enable = true
#   2. сеть pro-dev объявлена
#   3. dev-порты открыты на trustedInterfaces
#   4. docker / docker-compose / lazydocker / dive / ctop / trivy /
#      hadolint / sops / age доступны в systemPackages
#
# Usage: ./tests/contract/test_docker_dev.sh [HOST]
#        HOST defaults to huawei. Должно проходить для cf19, huawei,
#        desktop, vm.

HOST=${1:-huawei}
FLAKE="git+file://$(pwd)?submodules=1"
EVAL="nix --extra-experimental-features nix-command --extra-experimental-features flakes eval --json"

echo "Testing docker dev surface on host: $HOST"

# 1. docker daemon enabled
echo -n "  virtualisation.docker.enable = true... "
v=$($EVAL "$FLAKE#nixosConfigurations.$HOST.config.virtualisation.docker.enable" 2>/dev/null)
if [ "$v" = "true" ]; then
  echo "ok"
else
  echo "FAIL (got: $v)" >&2
  exit 1
fi

# 2. pro-dev network systemd unit declared
echo -n "  docker-network-pro-dev systemd unit exists... "
v=$($EVAL "$FLAKE#nixosConfigurations.$HOST.config.systemd.services.docker-network-pro-dev.serviceConfig.ExecStart" 2>/dev/null)
if echo "$v" | grep -q "172.20.0.0/16"; then
  echo "ok"
else
  echo "FAIL (got: $v)" >&2
  exit 2
fi

# 3. dev ports in firewall per-interface config
echo -n "  firewall opens 3000/5000/5173/8000/8080/8443 on lo... "
v=$($EVAL "$FLAKE#nixosConfigurations.$HOST.config.networking.firewall.interfaces.lo.allowedTCPPorts" 2>/dev/null)
for port in 3000 5000 5173 8000 8080 8443; do
  if ! echo "$v" | grep -q "$port"; then
    echo "FAIL (port $port not on lo)" >&2
    exit 3
  fi
done
echo "ok"

# 4. all required binaries in systemPackages
echo -n "  docker / docker-compose / credential-helpers in systemPackages... "
pkgs=$($EVAL "$FLAKE#nixosConfigurations.$HOST.config.environment.systemPackages" 2>/dev/null)
for name in docker docker-compose docker-credential-helpers; do
  if ! echo "$pkgs" | grep -qi "$name"; then
    echo "FAIL ($name missing)" >&2
    exit 4
  fi
done
echo "ok"

# 5. dev utilities in systemPackages (pro-dev.nix)
echo -n "  lazydocker / dive / ctop / trivy / hadolint / sops / age... "
pkgs=$($EVAL "$FLAKE#nixosConfigurations.$HOST.config.environment.systemPackages" 2>/dev/null)
for name in lazydocker dive ctop trivy hadolint sops age; do
  if ! echo "$pkgs" | grep -qi "$name"; then
    echo "FAIL ($name missing)" >&2
    exit 5
  fi
done
echo "ok"

# 6. emacs 'docker' in providedPackages
echo -n "  emacs 'docker' in providedPackages... "
v=$($EVAL "$FLAKE#nixosConfigurations.$HOST.config.home-manager.users.az.pro.emacs.providedPackages" 2>/dev/null | grep -qw docker && echo "yes" || echo "no")
if [ "$v" = "yes" ]; then
  echo "ok"
else
  echo "FAIL" >&2
  exit 6
fi

echo "Docker dev surface check: OK for $HOST"
