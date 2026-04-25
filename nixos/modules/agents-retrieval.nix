{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.agents.retrieval;
in

{
  options = {
    services.agents.retrieval = {
      enable = mkEnableOption "Enable local retrieval (sqlitevec/chroma-lite/qdrant)";
      # engine: sqlitevec | chroma | qdrant
      engine = mkOption {
        type = types.enum [ "sqlitevec" "chroma" "qdrant" ];
        default = "sqlitevec";
        description = ''
          Какой движок использовать для векторного хранилища.
          По умолчанию — sqlitevec (локальная простая реализация).
        '';
      };
      dataPath = mkOption {
        type = types.str;
        default = "/var/lib/agents/retrieval";
        description = "Путь для хранения индекса/базы retrieval";
      };
      listenAddress = mkOption {
        type = types.str;
        default = "127.0.0.1:32500";
        description = "Адрес, на котором будет слушать HTTP shim retrieval (если применимо)";
      };
    };
  };

  # Реализация модуля: по умолчанию просто создаём путь для данных и даём
  # systemd unit-шаблон, который оператор наполнит реализацией (derivation)
  # или используем devShell для запуска локального сервера во время разработки.
  config = mkIf cfg.enable {
    environment.directories = {
      # Создаём каталог хранения индекса, доступный для сервиса
      agents_retrieval = { path = cfg.dataPath; mode = "0755"; };
    };

    # Пример systemd unit: запускает скрипт, который должен быть положен
    # в /etc/agents/retrieval-server.py (может быть сгенерирован из derivation)
    systemd.services.agents-retrieval = {
      description = "Agents Retrieval Service (sqlitevec/chroma/qdrant wrapper)";
      wants = [ "network.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        ExecStart = ''${pkgs.python3}/bin/python3 /etc/agents/retrieval-server.py --data ${cfg.dataPath} --listen ${cfg.listenAddress}'';
        Restart = "on-failure";
        RestartSec = 5;
        Slice = "agents.slice";
      };
      install.wantedBy = [ "multi-user.target" ];
    };

    # Поумолчанию оставляем файл-источник пустым — оператор/flake должен
    # поместить реализацию в /etc/agents/retrieval-server.py или указать
    # производную в environment.systemPackages.
    environment.etc."agents/retrieval-server.py".text = ''
#!/bin/sh
# Placeholder retrieval server. Replace with a real server implementation
echo "Retrieval server placeholder - please install actual server" >&2
exit 1
'';
  };
}
