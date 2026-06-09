{ lib, pkgs, config, ... }:

# Интеграция SearXNG как systemd-сервиса.
# - Пакет searxng берётся из nixpkgs.
# - Сервис привязывается к loopback по умолчанию.
# - secret_key НЕ хранится в nix-store. Авто-генерится в /var/lib/searxng/env
#   через system.activationScripts при первом запуске и читается systemd-ом
#   через EnvironmentFile. В settings.yml — литерал `$SEARXNG_SECRET_KEY`,
#   который SearXNG раскрывает на старте (стандартная фича SearXNG).
# - Список engines выверен под self-hosted: оставлены только реально
#   работающие (google/brave/qwant/startpage аггрессивно блокируют SearXNG).

let
  cfg = config.services.searxng;
  listenParts = lib.splitString ":" cfg.listen;
  host = builtins.elemAt listenParts 0;
  port = builtins.elemAt listenParts 1;
  stateDir = "/var/lib/searxng";
  envFile = "${stateDir}/env";
in
{
  options.services.searxng = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
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

    engines = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "duckduckgo"
        "bing"
        "mojeek"
        "wiby"
        "marginalia"
        "wikipedia"
      ];
      description = ''
        Список SearXNG-движков для self-hosted instance.
        Дефолт выверен под клиентов без API-ключей и без публичного IP:
        - duckduckgo, bing, mojeek — основной поиск (стабильны)
        - wiby — small-web index (дополняет основные)
        - marginalia — independent index (дополняет)
        - wikipedia — энциклопедия
        Намеренно НЕ включены: google/brave/qwant/startpage (агрессивно
        блокируют self-hosted SearXNG: 403, rate-limit, timeout).
      '';
    };

    formats = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "html" "json" ];
      description = ''
        Форматы выдачи SearXNG. JSON нужен для программных клиентов
        (pi-searxng, MCP-серверы, скрипты).
      '';
    };

    settingsText = lib.mkOption {
      type = lib.types.str;
      default = ''
        use_default_settings:
          engines:
            keep_only:
        ${lib.concatMapStringsSep "\n" (e: "      - ${e}") cfg.engines}
        server:
          secret_key: "$SEARXNG_SECRET_KEY"
          base_url: "http://127.0.0.1:8888"
          limiter: false
          public_instance: false
        search:
          formats:
        ${lib.concatMapStringsSep "\n" (f: "    - ${f}") cfg.formats}
          default_lang: "en"
          safe_search: 0
          autocomplete: ""
        outgoing:
          request_timeout: 5.0
          max_request_timeout: 15.0
          pool_connections: 100
          pool_maxsize: 20
          enable_http2: true
        engines:
        ${lib.concatMapStringsSep "\n" (e : "  - name: ${e}\n    disabled: false") cfg.engines}
      '';
      description = ''
        Текст settings.yml, записываемый в /etc/searxng/settings.yml.
        - `use_default_settings.engines.keep_only` отфильтровывает все дефолтные
          engines кроме перечисленных в `cfg.engines` (избавляемся от спама в
          логах от google/qwant/startpage, которые блокируют self-hosted).
        - Содержит литерал `$SEARXNG_SECRET_KEY` — SearXNG раскрывает его
          на старте из EnvironmentFile.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
    environment.etc."searxng/settings.yml".text = cfg.settingsText;

    networking.firewall.allowedTCPPorts = lib.mkDefault [
      (lib.strings.toInt port)
    ];

    # Авто-генерация секрета вне nix-store. Выполняется на каждом switch,
    # но реальная запись — только если файла нет (idempotent).
    system.activationScripts.searxng-secret = {
      text = ''
        set -e
        install -d -m 0750 -o root -g root ${stateDir}
        if [ ! -s ${envFile} ]; then
          KEY=$(${pkgs.coreutils}/bin/head -c 32 /dev/urandom | ${pkgs.coreutils}/bin/od -An -tx1 | ${pkgs.coreutils}/bin/tr -d ' \n')
          ${pkgs.coreutils}/bin/printf 'SEARXNG_SECRET_KEY=%s\n' "$KEY" > ${envFile}
          ${pkgs.coreutils}/bin/chmod 0400 ${envFile}
        fi
      '';
      deps = [ ];
    };

    systemd.services.searxng = {
      description = "SearXNG - metasearch engine";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        Type = "simple";
        EnvironmentFile = envFile;
        ExecStart = "${cfg.package}/bin/searxng-run --config ${cfg.settingsFile} --host ${host} --port ${port}";
        Restart = "on-failure";
        RestartSec = "5s";
        CPUQuota = "50%";
        MemoryMax = "512M";
        StateDirectory = "searxng";
        StateDirectoryMode = "0750";
      };
    };
  };
}
