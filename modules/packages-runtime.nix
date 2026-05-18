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
{ config, pkgs, lib, piPkg ? null, ... }:

let
  emacsPkg = pkgs.emacs30 or pkgs.emacs;
   # opencode removed
in

# Minimal runtime packages that must be present in the final system profile.
# Keep this list intentionally small: these packages are required for system
# activation, shell access, and basic maintenance.

with pkgs;

{
  # Общая системная поверхность пакетов задаётся здесь: хосты больше не
  # финализируют общий список и не собирают его вручную.
  # Compose environment.systemPackages from smaller sets to make it easy to
  # select minimal subsets for host compositions.
  let
    baseSets = import ./package-sets/runtime.nix { inherit pkgs; };
    devSets = import ./package-sets/dev.nix { inherit pkgs; };
    exwmSets = import ./package-sets/exwm.nix { inherit pkgs; };
    other = import ../system-packages.nix { inherit pkgs; emacsPkg = pkgs.emacs30 or pkgs.emacs; enableOptional = false; };
  in
  environment.systemPackages = lib.mkAfter (with pkgs; baseSets.runtimePackages ++ devSets.devPackages ++ exwmSets.exwmPackages ++ other.packages);

# Last reviewed: 2026-05-03
}
