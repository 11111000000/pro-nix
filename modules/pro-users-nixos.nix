{ config, lib, pkgs, ... }:

let
  users = [ "az" "zo" "la" "bo" ];
in
{
  home-manager = {
    extraSpecialArgs = { inherit pkgs; };
    backupFileExtension = "backup";
    useUserPackages = true;
  };

  home-manager.users = builtins.listToAttrs (map (name: {
    inherit name;
    value = {
      imports = [ ../emacs/home-manager.nix ];
      home.username = name;
      home.homeDirectory = "/home/${name}";
      home.stateVersion = "23.11";
      pro.emacs = {
        enable = true;
        gui.enable = true;
      };
    };
  }) users);
}
