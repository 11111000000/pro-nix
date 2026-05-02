# modules/systemd-policy.nix
# Название: modules/systemd-policy.nix — минимальная точка входа для polity/systemd
# Кратко: предоставляет безопасную, неинвазивную заготовку для systemd/polkit
# и служит placeholder для импорта в configuration.nix.
#
# Цель:
#   Обеспечить минимальную, проверяемую точку входа для системных политик, не
#   навязывая глобальных изменений. Более сложные политики оформляются отдельно
#   через Change Gate.
#
# Контракт:
# - Вход: стандартные аргументы NixOS-модуля { config, pkgs, lib, ... }.
# - Эффект: возвращает безопасный набор options/config без принудительных изменений;
#   модуль предназначен для импорта (composition) и не должен использовать lib.mkForce.
# - Побочные эффекты: отсутствуют при значении опций по умолчанию.
#
# Как проверить (Proof):
# - Локальная проверка flake: `nix flake check`.
# - Линтер документации SURFACE/HOLO: `./tools/surface-lint.sh`.
#
# Last reviewed: 2026-05-02

{ config, pkgs, lib, ... }:

{
  # Этот модуль намеренно минимален: он не навязывает глобальные политики.
  # Его присутствие требуется в flake / configuration imports для корректной
  # работы проверок. Более сложные политики (oomd, polkit ordering, dbus)
  # добавляются отдельно через целевые PR с Proof.
  options = {
    systemdPolicy.example = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Пример опции-заглушки для модулей systemd policy";
    };
  };

  config = lib.mkIf config.systemdPolicy.example {
    # По умолчанию ничего не меняем; опция служит для тестирования и примера.
  };

}
