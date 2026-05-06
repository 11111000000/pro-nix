{ config, pkgs, lib, opencode_from_release ? null, ... }:

# Назначение: модуль управления доставкой opencode и установкой шаблона.
# Инварианты:
# - Опция `provisioning.opencode.enable` включает системную доставку opencode.
# - Конкретный бинарник должен определяться без зависимости от host-файлов.
# - Шаблон конфигурации новых пользователей должен быть задаваемым декларативно.

let
  defaultTemplate = ''${toString ./../docs/opencode-default-config.json}'';
  emacsPkg = pkgs.emacs30 or pkgs.emacs;
  opencodePkg = if opencode_from_release != null then opencode_from_release else (import ../../system-packages.nix { inherit pkgs emacsPkg; enableOptional = false; }).opencodeBin;
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
        description = "Если true, установить opencode system-wide.";
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
  # Реализация:
  # - При включении модуля добавляем opencode в системный профиль.
  # - Если flake передал готовую сборку, используем её.
  # - Иначе используем репозитарный opencodeBin из system-packages.nix.
  # - Шаблон конфигурации кладём в /etc/skel/pro-templates.
  config = lib.mkIf (config.provisioning.opencode.enable or true) {
    environment.systemPackages = [ opencodePkg ];

    environment.etc."skel/pro-templates/.opencode/config.json".source = lib.mkDefault config.provisioning.opencode.userTemplate;
  };
}
