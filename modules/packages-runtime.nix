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
{ pkgs, lib, ... }:

/* RU: Файловый контракт:
   Цель: предоставлять минимальный и стабильный набор рантайм-пакетов, необходимых
     для активации и поддержки системы.
   Контракт: модуль публикует общий список пакетов через additive-композицию.
   Побочные эффекты: добавляет системные утилиты, Emacs runtime и общие CLI.
   Proof: tests/contract/test_runtime_packages.sh
   Last reviewed: 2026-05-02
*/

{
  # Общая системная поверхность пакетов задаётся здесь: хосты больше не
  # финализируют общий список и не собирают его вручную.
  environment.systemPackages = lib.mkAfter (with pkgs; [
    bashInteractive
    openssh
    python3
    coreutils
    # steam-run provides an FHS-compatible runtime wrapper used by some
    # prebuilt upstream binaries (bubblewrap-based). Include it here so the
    # opencode wrapper can use steam-run as a fallback executor on hosts that
    # allow unprivileged user namespaces.
    steam-run
    procps
    dbus
  ] ++ (import ../system-packages.nix {
    inherit pkgs;
    emacsPkg = pkgs.emacs30 or pkgs.emacs;
    enableOptional = false;
  }).packages);

# Last reviewed: 2026-05-03
}
