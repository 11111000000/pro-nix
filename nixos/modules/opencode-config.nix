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

  config = lib.mkIf config.opencode.enable {
    system.activationScripts.opencode-default-config = {
      text = lib.concatStringsSep "\n" [
        "#!/bin/sh -e"
        "# Create opencode user config if missing"
        "for u in $(awk -F: '{ if ($3 >= 1000 && $1 != \"nobody\") print $1 }' /etc/passwd); do"
        "  homedir=$(getent passwd \"$u\" | cut -d: -f6)"
        "  target=\"$homedir/.opencode/config.json\""
        "  if [ ! -e \"$target\" ]; then"
        "    if [ -n \"$OPENCODE_TEMPLATE\" ]; then"
        "      cp -n \"$OPENCODE_TEMPLATE\" \"$target\" || true"
        "    else"
        "      mkdir -p \"$(dirname \"$target\")\""
        "      cp -n \"${config.opencode.userTemplate}\" \"$target\" || true"
        "    fi"
        "    chown $u:$u \"$target\" || true"
        "  fi"
        "done"
      ];
      # textInteractive removed: not a valid option for activation scripts in
      # this NixOS release. Keep script minimal and non-interactive.
    };
  };
}
