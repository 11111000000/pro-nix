# Название: modules/pro-users-termux.nix — Home Manager для Termux
# Summary (EN): Home Manager configuration for Termux (Android) users
# Цель:
#   Termux-специфичная часть Home Manager: отключает GUI для терминальной среды Android.
# Контракт:
#   Опции: pro.emacs.gui.enable = false
#   Побочные эффекты: настраивает Emacs для Termux.
# Предпосылки:
#   Требуется Termux + Home Manager.
# Как проверить (Proof):
#   После `termux-login-emacs` — запускается в терминале.
# Last reviewed: 2026-05-02
# Файл: автосгенерированная шапка — комментарии рефакторятся
/* RU: Rationale: Termux environment requires terminal-only Emacs configuration.
   Keep GUI disabled and ensure home-manager sets portable profile that works in Android.
   Proof: start Emacs under Termux and run headless ERT for Emacs profile.
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
