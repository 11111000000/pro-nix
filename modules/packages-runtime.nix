# Название: modules/packages-runtime.nix — Базовые рантайм-пакеты
# Summary (EN): Core runtime packages required for activation and shell access
/* RU: Базовый набор runtime-пакетов, необходимых для активации системы и доступа к shell.
   Комментарии ниже объясняют почему пакеты не должны быть форсированы в top-level без явной нужды.

  Файловый контракт:
  Цель: обеспечить минимальный набор утилит, необходимых для корректной активации
    и работы вспомогательных скриптов (`activate`, `ensure-perms`, helpers).
  Контракт: environment.systemPackages должен использовать lib.mkDefault в модулях;
    финальное решение о наборе пакетов принимается на уровне хоста.
  Proof: tests/contract/test_runtime_packages.sh
*/
# Цель:
#   Определить минимальный набор пакетов, необходимых для активации,
#   shell-доступа и базового обслуживания системы. Остальные пакеты
#   добавляются через environment.systemPackages или отдельные модули.
# Контракт:
#   Опции: environment.systemPackages (базовый список,可以被 дополнен)
#   Побочные эффекты: добавляет bashInteractive, openssh, coreutils, procps, dbus.
# Предпосылки:
#   Используется в NixOS-конфигурации; пакеты должны присутствовать в pkgs.
# Как проверить (Proof):
#   `nix eval .#nixosConfigurations.<host>.config.environment.systemPackages --json | jq -r '.[]' | grep -E '^bash|^openssh'`
# Last reviewed: 2026-04-25
{ config, pkgs, lib, ... }:

# Minimal runtime packages that must be present in the final system profile.
# Keep this list intentionally small: these packages are required for system
# activation, shell access, and basic maintenance.

with pkgs;

# Export as a NixOS module so it can be reliably included via `imports` and
# also imported directly to read the list (as configuration.nix does).
{
  # Модуль экспортирует базовый набор рантайм‑пакетов. Он использует
  # lib.mkDefault в местах, где другие модули могут дополнять список.
  environment.systemPackages = lib.mkDefault (with pkgs; [
    bashInteractive
    openssh
    coreutils
    procps
    dbus
    # Privacy transports: include transport clients so Tor transports are
    # available when services.tor.client is enabled by default in pro-privacy.
    obfs4proxy
    meek-client
    snowflake-client
  ]);
}
