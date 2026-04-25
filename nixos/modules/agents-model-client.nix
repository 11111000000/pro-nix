{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.agents.modelClient;
in

{
  options = {
    services.agents.modelClient = {
      enable = mkEnableOption "Enable agents model client proxy";
      listenAddress = mkOption {
        type = types.str;
        default = "127.0.0.1:31415";
        description = "Address for model client to bind to";
      };
      envFile = mkOption {
        type = types.str;
        default = "/etc/agents/model-client.env";
        description = "Path to environment file containing MODEL_API_URL and keys";
      };
      slice = mkOption {
        type = types.str;
        default = "agents.slice";
        description = "systemd slice for model client service";
      };
    };
  };

  config = mkIf cfg.enable {
    systemd.services.agents-model-client = {
      description = "Agents Model Client Proxy";
      wants = [ "network.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        # Запускаем model-client из установленного пути -- предполагается,
        # что derivation положит исполняемый модуль в /run/current-system/sw/bin/model-client
        ExecStart = ''${pkgs.python3}/bin/python3 -m apps.model-client.app '';
        Restart = "on-failure";
        RestartSec = 5;
        Slice = cfg.slice;
      };
      install.wantedBy = [ "multi-user.target" ];
    };
    # create directory for agent artifacts
    environment.etc."agents".source = null;
  };
}
