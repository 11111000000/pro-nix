# Файл: автосгенерированная шапка — комментарии рефакторятся
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
