{ config, pkgs, lib, opencode_from_release ? null, ... }:

let
  # Этот вспомогательный модуль устарел: новая авторитетная реализация опций
  # и установки opencode находится в nixos/modules/opencode.nix. Чтобы избежать
  # рассинхронизации и дублирования опций, здесь сохраняем лёгкую обратную
  # совместимость, но делегируем реальную логику основному модулю.
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
    environment.systemPackages = lib.mkDefault (if opencode_from_release != null then [ opencode_from_release ] else []);
  };
}
