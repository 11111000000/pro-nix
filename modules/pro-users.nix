# Название: modules/pro-users.nix — Базовые пользователи и sudo правила
# Summary (EN): Declare standard user accounts and sudo policy for the fleet
# Цель:
#   Создать стандартный набор пользовательских учётных записей и централизовать
#   политику sudo для управляемых хостов, чтобы упростить администрирование.
# Контракт:
#   Опции: нет специфичных опций кроме импорта модуля; поведение задаётся внутри.
#   Побочные эффекты: добавляет users.users для учёток az, za, la, bo; создаёт
#   группы pro, netdev и pro-agent; задаёт security.sudo.extraRules.
# Предпосылки / Риски:
#   NOPASSWD в sudo упрощает управление, но повышает риск при компрометации
#   учётной записи — внимательно следите за списком пользователей и аудитом.
# Как проверить (Proof):
#   Проверить наличие пользователей: `id az` на хосте или `nix eval .#...`;
#   Поведение sudo: `sudo -l -U az` после сборки.
# Last reviewed: 2026-05-02
{ config, pkgs, lib, emacsPkg ? pkgs.emacs, ... }:

/* RU: Файловый контракт — Пользователи и sudo
   Цель: определить стандартные учётные записи и безопасную, но удобную sudo политику для управляемых хостов.
   Контракт: модуль предоставляет users.users, users.groups и security.sudo.extraRules; изменения должны быть idempotent.
   Побочные эффекты: создание пользователей, групп и правил sudo; администрирование требует внимательного аудита.
   Proof: nix eval .#nixosConfigurations.<host>.config.users.users; sudo -l -U az
   Last reviewed: 2026-05-02
*/

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
  }) [ "az" "za" "la" "bo" ]);

  # Локальная служебная группа для дополнительных прав/доступов, используемых
  # внутри репозитория и вспомогательных сервисов.
  users.groups.pro = { };
  # Группа netdev требуется некоторыми D-Bus policy файлами (например, для
  # сетевых сервисов). Если группы нет, dbus выдаёт "Unknown group \"netdev\""
  # и reload может срываться во время `nixos-rebuild switch`.
  users.groups.netdev = { };

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
  # Make sudo extra rules additive so hosts can augment/restrict them.
  security.sudo.extraRules = lib.mkDefault ([
    {
      users = [ "az" "za" "la" "bo" ];
      commands = [ { command = "ALL"; options = [ "NOPASSWD" ]; } ];
    }
  ]);

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
