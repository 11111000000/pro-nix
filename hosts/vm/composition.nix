{ pkgs, ... }:

let
  runtime = import ../../modules/system-package-sets-runtime.nix { inherit pkgs; };
  dev = import ../../modules/system-package-sets-dev.nix { inherit pkgs; };
  exwm = import ../../modules/system-package-sets-exwm.nix { inherit pkgs; };
  privacy = import ../../modules/system-package-sets-privacy.nix { inherit pkgs; };
in
{
  environment.systemPackages = with pkgs;
    runtime.runtimePackages
    ++ dev.devPackages
    ++ exwm.exwmPackages
    ++ privacy.privacyPackages
    ++ [ gh tor-browser ];
}
