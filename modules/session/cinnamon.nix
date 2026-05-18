{ config, pkgs, ... }:

{
  # Cinnamon is intentionally isolated as the heavy desktop branch.
  # It remains available for hosts that want the full GUI surface, but it is
  # not part of the minimal EXWM workstation composition.
  services.xserver.desktopManager.cinnamon.enable = true;
}
