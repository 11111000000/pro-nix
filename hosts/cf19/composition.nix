{ lib, pkgs, ... }:

let
  runtime = import ../../modules/system-package-sets-runtime.nix { inherit pkgs; };
  tor = import ../../modules/system-package-sets-tor.nix { inherit pkgs; };
in
{
  # CF-19 использует EXWM как минимальную графическую среду и отдельно
  # получает компактный прикладной desktop-слой без тяжёлого desktop branch.
  pro.profiles.exwmMinimal.enable = lib.mkDefault true;

  # Базовый runtime + tor-утилиты. runtimePackages — единый «доступно всем»
  # набор (bash, openssh, emacs, obsidian, ...). tor-утилиты нужны на
  # каждом хосте, включая EXWM-лэптоп с Android-AP (см. README.md и
  # docs/analyse/...).
  environment.systemPackages = runtime.runtimePackages ++ tor.torControlPackages;
}
