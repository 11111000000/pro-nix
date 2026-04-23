{ config, pkgs, lib, ... }:

let
  opencode = config.provisioning.opencode.enable or false;
in {
  options.provisioning.opencode = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "If true, install opencode system-wide for all users via opencode_from_release.";
    };
  };

  config = lib.mkIf opencode {
    # Expose the deterministic opencode_from_release derivation into systemPackages
    # so every user gets the same binary without per-user bootstrap.
    environment.systemPackages = lib.mkForce (config.environment.systemPackages or []) ++ [ (config.environment.opencodePackage or pkgs.opencode-from-release) ];
  };
}
