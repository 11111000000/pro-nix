{ config, pkgs, lib, ... }:

let
  opencode_user_dir = lib.mkOptionName "opencode.userDir";
in {
  options = {
    opencode = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "If true, install default opencode config to users' home if missing.";
      };
      userTemplate = lib.mkOption {
        type = lib.types.str;
        default = ''${toString ./../docs/opencode-default-config.json}'';
        description = "Path to default opencode config template to install when missing.";
      };
    };
  };

  # Switching to a generic templates mechanism: the universal user-templates
  # module installs repo templates into /etc/skel/pro-templates and user
  # home-manager copies them into user homes if missing.
  config = lib.mkIf config.opencode.enable {
    # Keep the option so hosts can override the shipped template path.
    opencode = config.opencode or {};
  };
}
