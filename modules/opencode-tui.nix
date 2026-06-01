{ config, lib, pkgs, ... }:

let
  cfg = config.pro.opencode.tui;

in {
  options.pro.opencode.tui = {
    enable = lib.mkEnableOption "OpenCode TUI config";
  };

  config = lib.mkIf cfg.enable {
    home.file.".config/opencode/tui.json".text = builtins.toJSON {
      "$schema" = "https://opencode.ai/tui.json";
      plugin = [ ];
    };

  };

}
