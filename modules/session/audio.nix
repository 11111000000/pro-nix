{ config, pkgs, ... }:

{
  # Audio belongs to the session, but it is not specific to EXWM itself.
  # We keep it explicit because the desktop stack is easier to reason about
  # when the sound subsystem is a separate layer.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };
}
