# Название: modules/packages-runtime.nix — Базовые рантайм-пакеты
# Кратко: минимальный набор пакетов, необходимых для активации системы и базовых операций.
#
# Файловый контракт:
#   Цель: обеспечить системный набор утилит, необходимых для активации,
#     shell-доступа и общих пользовательских сценариев.
#   Контракт: environment.systemPackages собирается композиционно на уровне системы;
#     модуль не зависит от host-level финализации.
#   Proof: tests/contract/test_runtime_packages.sh
#
# Цель:
#   Определить минимальный набор пакетов, необходимых для активации, shell-доступа
#   и базового обслуживания системы. Остальные пакеты добавляются через environment.systemPackages или отдельные модули.
#
# Контракт:
#   Опции: environment.systemPackages (базовый список, может быть дополнен)
#   Побочные эффекты: добавляет bashInteractive, openssh, coreutils, procps, dbus.
#
# Предпосылки:
#   Используется в NixOS-конфигурации; пакеты должны присутствовать в pkgs.
#
# Как проверить (Proof):
#   `nix eval .#nixosConfigurations.<host>.config.environment.systemPackages --json | jq -r '.[]' | grep -E '^bash|^openssh'`
#
# Last reviewed: 2026-05-03
{ pkgs, ... }:

{
  # Мы намеренно держим этот слой узким: это не рабочая станция и не desktop,
  # а только та опорная точка, без которой система не оживает.
  environment.systemPackages = with pkgs; [
    bashInteractive
    openssh
    python3
    coreutils
    procps
    dbus
    gawk
  ];
}
