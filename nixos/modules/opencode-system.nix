{ config, pkgs, lib, opencode_from_release ? null, ... }:

let
  opencode = config.provisioning.opencode.enable or true;
in {
  options.provisioning.opencode = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "If true, install opencode system-wide for all users via opencode_from_release.";
    };
  };

  config = lib.mkIf opencode {
    # Expose the deterministic opencode_from_release derivation into systemPackages
    # so every user gets the same binary without per-user bootstrap. Prefer
    # the opencode_from_release provided by the flake; if not available, do
    # not add a package (to avoid referencing undefined derivations).
    environment.systemPackages = lib.mkForce (config.environment.systemPackages or []) ++ (if opencode_from_release != null then [ opencode_from_release ] else []);
  };
}
