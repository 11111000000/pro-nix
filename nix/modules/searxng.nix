{ lib, pkgs, config, ... }:

# Минимальная интеграция SearXNG как systemd-сервиса.
# - Использует пакет searxng из nixpkgs (если отсутствует можно поставить override в local.nix)
# - Размещает конфиг в /etc/searxng/settings.yml (operator может заменить файл)
# - Предоставляет простой systemd service, совместимый с `systemd-analyze verify`.

let
  searxPkg = pkgs.searxng;
  runWrapper = pkgs.writeShellScriptBin "searxng-run" ''
    #!/usr/bin/env bash
    set -euo pipefail
    exec ${searxPkg}/bin/searxng "$@"
  '';
in

{
  options = {
    services.searxng = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable SearXNG service";
      };
      settingsFile = lib.mkOption {
        type = lib.types.str;
        default = "/etc/searxng/settings.yml";
        description = "Path to SearXNG settings.yml (managed by operator).";
      };
      listen = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1:8888";
        description = "Address:port for SearXNG to bind to.";
      };
    };
  };

  config = lib.mkIf config.services.searxng.enable {
    environment.systemPackages = [ searxPkg ];

    # Install an example settings template if operator didn't provide one.
    environment.etc."searxng/settings.yml".source = lib.optionalString (builtins.pathExists ./../../searxng/settings.yml) ./searxng/settings.yml;

    systemd.services.searxng = {
      description = "SearXNG search engine";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        EnvironmentFile = "${config.services.searxng.settingsFile}";
        ExecStart = "${runWrapper}/bin/searxng --host ${lib.escapeShellArg (lib.splitString ":" config.services.searxng.listen | builtins.head)} --port ${lib.escapeShellArg (lib.splitString ":" config.services.searxng.listen | builtins.elemAt 1)}";
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };
  };

  # Return module
  {
    inherit options config;
  }
}
