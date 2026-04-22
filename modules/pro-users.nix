# modules/pro-users.nix
# Назначение: декларация базовых пользовательских аккаунтов и правил sudo для
# репозитория pro-nix.
#
# Описание:
# - Создаёт набор системных пользователей (az, zo, la, bo) с минимальными
#   профилями и нужными группами для работы рабочего окружения (networkmanager,
#   bluetooth, docker и т.д.).
# - Обеспечивает явную установку правил sudo для этих пользователей. Это
#   намеренная системная политика: управление привилегиями централизовано в
#   модуле, а каждый хост лишь импортирует его.
#
# Правило оформления:
# - Комментарии здесь описывают политику (что и почему), не технические мелочи
#   реализации; низкоуровневые замечания оставлены около соответствующих опций.

{ config, pkgs, lib, emacsPkg ? pkgs.emacs, ... }:

{
  # Создаём стандартные пользовательские учётные записи для этого коллектива.
  # Формируем список через listToAttrs для компактности конфигурации.
  users.users = builtins.listToAttrs (map (name: {
    inherit name;
    value = {
      isNormalUser = true;
      description = name;
      # Группы: необходимы для доступа к сетевым, вводным и dev-ресурсам.
      extraGroups = [ "networkmanager" "wheel" "bluetooth" "docker" "input" "uinput" "pro" "pro-agent" ];
      # Минимальный набор программ в пользовательском профиле.
      packages = with pkgs; [ git ];
      openssh.authorizedKeys.keys = [ ];
    };
  }) [ "az" "zo" "la" "bo" ]);

  # Локальная служебная группа для дополнительных прав/доступов, используемых
  # внутри репозитория и вспомогательных сервисов.
  users.groups.pro = { };

  # Политика sudo: явно включаем sudo и разрешаем пользователям группы wheel
  # получать права без запроса пароля. Это удобная политика для управляемых
  # машин в пределах этой коллекции хостов; при необходимости хост может
  # переопределить эту настройку.
  security.sudo.enable = true;
  security.sudo.wheelNeedsPassword = false;

  # Дополнительные правила sudo: разрешаем перечисленным пользователям запуск
  # любых команд без пароля (NOPASSWD). Это декларация доступа, следует
  # применять осторожно и контролировать список учёток.
  users.groups.pro-agent = {};
  security.sudo.extraRules = lib.mkForce ([
    {
      users = [ "az" "zo" "la" "bo" ];
      commands = [ { command = "ALL"; options = [ "NOPASSWD" ]; } ];
    }
  ] ++ [
    {
      groups = [ "pro-agent" ];
      commands = [
        # allow restarting systemd user services and reading journal for units
        { command = "/run/current-system/sw/bin/systemctl"; options = [ "NOPASSWD" ]; }
        { command = "/run/current-system/sw/bin/journalctl"; options = [ "NOPASSWD" ]; }
      ];
    }
  ]);

  # Disable requiretty only for pro-agent group so non-interactive agent
  # processes can use sudo for the allowed commands.
  security.sudo.extraConfig = lib.mkForce ''
Defaults:%pro-agent !requiretty
'';

  # Настройки home-manager, передаём инъекции аргументов и включаем
  # использование пользовательских пакетов.
  home-manager = {
    extraSpecialArgs = { inherit pkgs emacsPkg; };
    backupFileExtension = "backup";
    useUserPackages = true;
  };

  # Импорт вспомогательных NixOS-специфичных определений пользователей.
  imports = [
    ./pro-users-nixos.nix
  ];
}
