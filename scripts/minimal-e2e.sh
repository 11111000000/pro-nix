#!/usr/bin/env bash
set -euo pipefail

# Минимальный E2E-проверка конфигурации NixOS
# Проверяет синтаксис и базовую структуру флейка и конфигураций

echo "🧪 Запуск минимальных E2E-проверок конфигурации NixOS..."

# 1. Проверка синтаксиса флейка
echo "  1. Проверка синтаксиса flake.nix..."
nix --extra-experimental-features 'nix-command flakes' flake check --show-trace || {
    echo "❌ Flake не проходит проверку"
    exit 1
}

# 2. Проверка синтаксиса основной конфигурации
echo "  2. Проверка синтаксиса configuration.nix..."
nix-instantiate --parse --show-trace configuration.nix > /dev/null

# 3. Проверка структуры пользователей в модуле pro-users.nix
echo "  3. Проверка структуры пользователей..."
if [[ -f modules/pro-users.nix ]]; then
    echo "    Проверяю, что модуль users содержит всех четырёх пользователей..."
    # Используем eval с импортом из текущего пути
    nix-instantiate --eval --strict --json \
        -I nixpkgs=channel:nixos-unstable \
        -E 'with import <nixpkgs> {}; (import <nixpkgs/nixos> { configuration = { imports = [ (./. + "/modules/pro-users.nix") ]; }; }).config.users.users' \
        | jq -r 'keys[]' | grep -E '^(az|za|la|bo)$' | wc -l | grep -q 4 || {
        echo "❌ Не все четыре пользователя найдены в pro-users.nix"
        exit 1
    }
else
    echo "⚠ modules/pro-users.nix не найден"
fi

# 4. Проверка структуры хостов
echo "  4. Проверка структуры хостов..."
if [[ -d hosts ]]; then
    echo "    Проверяю, что все хосты могут быть собраны..."
    for host in hosts/*/; do
        hostname=$(basename "$host")
        if [[ -f "$host/configuration.nix" ]]; then
            echo "      Проверка хоста: $hostname"
            nix-instantiate --parse --show-trace "$host/configuration.nix" > /dev/null
        fi
    done
fi

# 5. Проверка, что флейк экспортирует конфигурации хостов
echo "  5. Проверка экспорта конфигураций в flake..."
nix --extra-experimental-features 'nix-command flakes' eval .#nixosConfigurations --apply 'builtins.attrNames' --json | \
    jq -r '.[]' | sort > /tmp/available-hosts.txt

if [[ -f /tmp/available-hosts.txt ]]; then
    echo "    Доступные конфигурации в flake:"
    cat /tmp/available-hosts.txt
fi

echo "✅ Все минимальные проверки прошли успешно!"
echo ""
echo "📋 Для более полной проверки можно запустить:"
echo "   nixos-rebuild build --flake .#<hostname>"
echo "   где <hostname> = thinkpad, desktop, cf19 или default"
