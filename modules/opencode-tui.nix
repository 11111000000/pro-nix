{ config, lib, pkgs, ... }:

let
  cfg = config.pro.opencode.tui;

  evanDbgSrc = pkgs.fetchFromGitHub {
    owner = "EvanDbg";
    repo = "opencode-sidebar-plugins";
    rev = "main";
    sha256 = "1nc8jnm26xg63f4i7a7pwjhq3xx8lc2nrh10pgaqf3fzy36w3v0c";
  };
in {
  options.pro.opencode.tui = {
    enable = lib.mkEnableOption "OpenCode TUI plugin config";

    plugins = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Список TUI плагинов opencode (npm-имена или абсолютные пути).";
    };

    enableSubagentStatusline = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Добавить opencode-subagent-statusline (npm) в TUI плагины.";
    };

    enableEvanDbgSidebar = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Добавить pepper-dashboard, hermes-sidebar и cmux-notify из EvanDbg/opencode-sidebar-plugins.";
    };
  };

  config = lib.mkIf cfg.enable (let
    pluginEntries = cfg.plugins
      ++ lib.optionals cfg.enableSubagentStatusline [ "opencode-subagent-statusline" ]
      ++ lib.optionals cfg.enableEvanDbgSidebar [
        "${config.home.homeDirectory}/.config/opencode/plugins/pepper-dashboard.tsx"
        "${config.home.homeDirectory}/.config/opencode/plugins/hermes-sidebar.tsx"
        "${config.home.homeDirectory}/.config/opencode/plugins/cmux-notify.ts"
      ];
  in {
    home.file.".config/opencode/tui.json".text = builtins.toJSON {
      "$schema" = "https://opencode.ai/tui.json";
      plugin = pluginEntries;
    };

    home.file.".config/opencode/package.json".text = builtins.toJSON {
      dependencies = {
        "@opencode-ai/plugin" = "1.4.10";
        "@opentui/solid" = "^0.2.1";
        "solid-js" = "^1.9.12";
      };
    };

    home.file.".config/opencode/plugins/pepper-dashboard.tsx" = lib.mkIf cfg.enableEvanDbgSidebar {
      source = "${evanDbgSrc}/pepper-dashboard.tsx";
    };

    home.file.".config/opencode/plugins/hermes-sidebar.tsx" = lib.mkIf cfg.enableEvanDbgSidebar {
      source = "${evanDbgSrc}/hermes-sidebar.tsx";
    };

    home.file.".config/opencode/plugins/cmux-notify.ts" = lib.mkIf cfg.enableEvanDbgSidebar {
      source = "${evanDbgSrc}/cmux-notify.ts";
    };

    home.activation.pro-opencode-tui-npm-deps = lib.mkIf cfg.enableEvanDbgSidebar ''
      if [ -d "$HOME/.config/opencode" ] && [ ! -d "$HOME/.config/opencode/node_modules" ]; then
        echo "pro-opencode-tui: installing npm dependencies for TUI plugins..."
        cd "$HOME/.config/opencode"
        npm install --ignore-scripts 2>/dev/null || \
          bun install --ignore-scripts 2>/dev/null || \
          echo "pro-opencode-tui: neither npm nor bun in PATH; run 'npm install' manually in ~/.config/opencode/"
      fi
    '';
  });
}
