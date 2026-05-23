{ lib, ... }:

{
  # CF-19 больше не собирает systemPackages вручную. Этот модуль только
  # включает профиль минимального EXWM-окружения, а базовый набор пакетов
  # формируется общими модулями (packages-runtime.nix, system-packages.nix).
  pro.profiles.exwmMinimal.enable = lib.mkDefault true;
}
