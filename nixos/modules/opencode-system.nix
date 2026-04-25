{ config, pkgs, lib, opencode_from_release ? null, ... }:

# Назначение: устаревшая обёртка для совместимости; делегирует реальную
# логику основному модулю nixos/modules/opencode.nix.
# Инвариант: изменения в этом модуле должны быть минимальными — он лишь
# обеспечивает совместимость и не добавляет новую логику.

let
  opencode = config.provisioning.opencode.enable or true;
in {
  # Поддерживаем старую опцию для обратной совместимости: если кто-то ещё
  # использует этот модуль напрямую, он будет работать, но реальная логика
  # централизована в nixos/modules/opencode.nix.
  options.provisioning.opencode = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Deprecated: use nixos/modules/opencode.nix. Если true, попытаться установить opencode system-wide.";
    };
  };

  config = lib.mkIf opencode {
    # Минимальная совместимость: если flake предоставляет opencode_from_release,
    # добавляем его в systemPackages через lib.mkDefault. Основной модуль
    # уже делает подобное и должен быть предпочтительным.
    # Add opencode deterministically as a low-priority contribution.
    environment.systemPackages = lib.mkDefault (if opencode_from_release != null then [ opencode_from_release ] else []);
  };
}
