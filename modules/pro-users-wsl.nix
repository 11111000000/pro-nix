# Название: modules/pro-users-wsl.nix — Home Manager для WSL
# Summary (EN): Home Manager configuration for WSL users
# Цель:
#   WSL-специфичная часть Home Manager: отключает gui для Windows-окружения.
# Контракт:
#   Опции: pro.emacs.gui.enable = false
#   Побочные эффекты: настраивает Emacs без GUI-компонента.
# Предпосылки:
#   Требуется WSL + Home Manager.
# Как проверить (Proof):
#   После wsl.exe -- emacs запускается в терминальном режиме.
# Last reviewed: 2026-04-25
# Файл: автосгенерированная шапка — комментарии рефакторятся
/* RU: Rationale: WSL requires terminal-only Emacs profile; avoid GUI-specific options.
   Proof: Emacs launches in terminal mode under wsl.exe and headless ERT passes.
*/
{ config, lib, pkgs, ... }:

{
  home-manager = {
    extraSpecialArgs = { inherit pkgs; };
    backupFileExtension = "backup";
    useUserPackages = true;
  };

  home-manager.users.${config.home.username} = {
    imports = [ ../emacs/home-manager.nix ];
    home.username = config.home.username;
    home.homeDirectory = config.home.homeDirectory;
    home.stateVersion = "23.11";
    pro.emacs = {
      enable = true;
      gui.enable = false;
    };
  };
}
