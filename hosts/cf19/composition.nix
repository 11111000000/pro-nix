{ pkgs, lib, ... }:

let
  # CF-19 should stay lean: enough for shell, Emacs, EXWM and the tools needed
  # to program and administer the machine, but not the heavy desktop bundle.
  runtime = import ../../modules/system-package-sets-runtime.nix { inherit pkgs; };
  dev = import ../../modules/system-package-sets-dev.nix { inherit pkgs; };
  exwm = import ../../modules/system-package-sets-exwm.nix { inherit pkgs; };
in
{
  # cf19 держит минимальный EXWM-набор; тяжёлые графические пакеты
  # собираются только в других профилях.
  environment.systemPackages = lib.mkForce (with pkgs;
    runtime.runtimePackages
    ++ dev.devPackages
    ++ exwm.exwmPackages
    ++ [ gh ]
  );
}
