{ pkgs, ... }:

let
  desktopHeavy = import ../../modules/system-package-sets-desktop-heavy.nix { inherit pkgs; };
  privacy = import ../../modules/system-package-sets-privacy.nix { inherit pkgs; };
  lsp = import ../../modules/system-package-sets-lsp.nix { inherit pkgs; };
  media = import ../../modules/system-package-sets-media.nix { inherit pkgs; };
  agent = import ../../modules/system-package-sets-agent.nix { inherit pkgs; };
  runtime = import ../../modules/system-package-sets-runtime.nix { inherit pkgs; };
  dev = import ../../modules/system-package-sets-dev.nix { inherit pkgs; };
  exwm = import ../../modules/system-package-sets-exwm.nix { inherit pkgs; };
in
{
  environment.systemPackages = with pkgs;
    runtime.runtimePackages
    ++ dev.devPackages
    ++ exwm.exwmPackages
    ++ agent.agentPackages
    ++ lsp.lspPackages
    ++ privacy.privacyPackages
    ++ media.mediaPackages
    ++ (import ../../modules/system-package-sets-desktop-heavy.nix { inherit pkgs; }).desktopHeavyPackages
    ++ [ tor-browser ];
}
