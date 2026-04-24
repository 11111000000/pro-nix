{ config, pkgs, lib, opencode_from_release ? null, ... }:

let
  # Путь по умолчанию к шаблону конфигурации, который будет устанавливаться в
  # /etc/skel/pro-templates/.opencode/config.json при включении модуля.
  # Файл лежит в репозитории в docs/opencode-default-config.json.
  defaultTemplate = ''${toString ./../docs/opencode-default-config.json}'';
in
{
  #############################
  # Опции модуля opencode
  #############################
  # Все настройки, относящиеся к opencode, сосредоточены в этом модуле.
  # Цель: никакой опencode‑специфичной логики или опций вне этого файла.
  options.provisioning = {
    # Пространство имён provisioning.* держит опции для системного provisioning-а
    # и сюда логично поместить опencode. Это минимизирует рассеяние опций по
    # разным модулям и сохраняет контракт ясным: все provisioning‑опции в одном
    # месте.
    opencode = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Если true, установить opencode system-wide (через опцию opencode_from_release, если она предоставлена flake).";
      };

      # Путь до шаблона конфигурации, который копируется для новых пользователей.
      # По умолчанию указывает на docs/opencode-default-config.json в репо.
      userTemplate = lib.mkOption {
        type = lib.types.str;
        default = defaultTemplate;
        description = "Путь до шаблона конфигурации для opencode, будет помещён в /etc/skel/pro-templates/.opencode/config.json";
      };
    };
  };

  #############################
  # Реализация
  #############################
  # Поведение модуля:
  # - Если включён (provisioning.opencode.enable = true), то пробуем добавить
  #   системный пакет opencode_from_release (если flake его предоставляет).
  # - Не пытаемся самостоятельно доставлять/скачивать бинарь здесь — это
  #   ответственность пакета/обёртки. Модуль только управляет тем, чтобы
  #   системный профиль содержал opencode, когда это допускается.
  # - Устанавливаем шаблон конфигурации в /etc/skel/pro-templates, чтобы при
  #   создании нового пользователя или при копировании из skel он получил
  #   базовый файл ~/.opencode/config.json.
  config = lib.mkIf (config.provisioning.opencode.enable or true) {
    # Добавляем системный пакет, если он доступен от flake/flake.nix через
    # аргумент opencode_from_release. Такой подход даёт флаг управления
    # версией (flake может предоставить готовую сборку opencode).
    environment.systemPackages = lib.mkDefault (if opencode_from_release != null then [ opencode_from_release ] else []);

    # Устанавливаем шаблон в /etc/skel/pro-templates, не перезаписывая
    # существующие пользовательские конфиги при активации.
    environment.etc."skel/pro-templates/.opencode/config.json".source = config.provisioning.opencode.userTemplate;
  };
}
