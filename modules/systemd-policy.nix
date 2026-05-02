# modules/systemd-policy.nix
# Краткий модуль: системные политики и мелкие исправления для systemd/polkit.
# Назначение: предоставить минимальную, безопасную точку входа для конфигурации,
# чтобы flake/eval корректно функционировали. Более полные настройки выделяются
# в отдельной задаче и оформляются через Change Gate.
#
# Контракт:
# - Вход: standard NixOS module args { config, pkgs, lib, ... }.
# - Эффект: возвращает пустой набор config (без принудительных изменений),
#   обеспечивает присутствие файла для `imports` в configuration.nix.

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
