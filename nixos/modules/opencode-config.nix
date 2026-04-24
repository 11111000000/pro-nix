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
    # Ensure opencode.slice exists and is usable via systemd-run wrappers
    systemd.services."opencode-slice-setup" = {
      description = "Ensure opencode.slice exists (no-op when slice present)";
      after = [ "local-fs.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "/bin/sh -c 'if [ ! -f /etc/systemd/system/opencode.slice ]; then echo \"opencode.slice not found\"; fi; exit 0'";
      };
      enable = true;
    };
  };
}
