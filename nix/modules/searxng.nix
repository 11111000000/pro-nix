{ lib, pkgs, config, ... }:

# Интеграция SearXNG как systemd-сервиса.
# - Пакет searxng берётся из nixpkgs.
# - Конфиг задаётся через /etc/searxng/settings.yml.
# - Сервис привязывается к loopback по умолчанию.

let
  cfg = config.services.searxng;
  listenParts = lib.splitString ":" cfg.listen;
  host = builtins.elemAt listenParts 0;
  port = builtins.elemAt listenParts 1;
in
{
  options.services.searxng = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Включить SearXNG.";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.searxng;
      description = "Пакет SearXNG.";
    };

    listen = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1:8888";
      description = "Адрес и порт для привязки.";
    };

    settingsFile = lib.mkOption {
      type = lib.types.str;
      default = "/etc/searxng/settings.yml";
      description = "Путь к settings.yml.";
    };

    settingsText = lib.mkOption {
      type = lib.types.str;
      default = ''
        server:
          secret_key: "changeme-replace-with-secure-random"
          base_url: "http://127.0.0.1:8888"
      '';
      description = "Текст settings.yml, записываемый в /etc/searxng/settings.yml.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
    environment.etc."searxng/settings.yml".text = cfg.settingsText;

    networking.firewall.allowedTCPPorts = lib.mkDefault [
      (lib.strings.toInt port)
    ];

    systemd.services.searxng = {
      description = "SearXNG - metasearch engine";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/searxng-run --config ${cfg.settingsFile} --host ${host} --port ${port}";
        Restart = "on-failure";
        RestartSec = "5s";
        CPUQuota = "50%";
        MemoryMax = "512M";
      };
    };
  };
}
