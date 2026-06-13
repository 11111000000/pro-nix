{ lib, pkgs, ... }:

let
  tor = import ../../modules/system-package-sets-tor.nix { inherit pkgs; };
in
{
  # CF-19 использует EXWM как минимальную графическую среду и отдельно
  # получает компактный прикладной desktop-слой без тяжёлого desktop branch.
  pro.profiles.exwmMinimal.enable = lib.mkDefault true;

  # Глобальные tor-утилиты (pro-tor CLI, torwrap). Доступны через PATH
  # после just switch — нужны на каждом хосте, включая EXWM-лэптоп с
  # Android-AP (см. README.md и docs/analyse/...).
  environment.systemPackages = tor.torControlPackages;
}
