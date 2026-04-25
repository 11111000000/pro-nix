{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.agents.control;
in

{
  options = {
    services.agents.control = {
      enable = mkEnableOption "Enable basic coordinator/worker control plane";
      useRedis = mkOption {
        type = types.bool;
        default = false;
        description = "Если true, использовать Redis как брокер очередей (опционально).";
      };
      redisUrl = mkOption {
        type = types.str;
        default = "redis://127.0.0.1:6379";
        description = "URL Redis, если useRedis = true";
      };
      transcriptsDir = mkOption {
        type = types.str;
        default = "/var/lib/agents/transcripts";
        description = "Где хранить результаты/транскрипты работы агентов";
      };
    };
  };

  config = mkIf cfg.enable {
    environment.directories = {
      agents_transcripts = { path = cfg.transcriptsDir; mode = "0755"; };
    };

    # Coordinator service
    systemd.services.agents-coordinator = {
      description = "Agents Coordinator Service";
      wants = [ "network.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        ExecStart = ''${pkgs.python3}/bin/python3 /etc/agents/coordinator.py'';
        Restart = "on-failure";
        RestartSec = 5;
        Slice = "agents.slice";
      };
      install.wantedBy = [ "multi-user.target" ];
    };

    # Worker template: one worker per instance name
    systemd.services."agents-worker@" = {
      description = "Agents Worker Template";
      serviceConfig = {
        ExecStart = ''${pkgs.python3}/bin/python3 /etc/agents/worker.py'';
        Restart = "on-failure";
        RestartSec = 5;
        Slice = "agents.slice";
      };
    };

    # Placeholder files - operators should place actual implementations via flake outputs
    environment.etc."agents/coordinator.py".text = ''
#!/bin/sh
echo "Coordinator placeholder - install real coordinator in /etc/agents/coordinator.py"
exit 1
'';

    environment.etc."agents/worker.py".text = ''
#!/bin/sh
echo "Worker placeholder - install real worker in /etc/agents/worker.py"
exit 1
'';
  };
}
