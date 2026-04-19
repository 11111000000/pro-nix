# modules/pro-users.nix: Ядро пользовательской конфигурации NixOS

{ config, pkgs, lib, emacsPkg ? pkgs.emacs, ... }:

{
  users.users = builtins.listToAttrs (map (name: {
    inherit name;
    value = {
      isNormalUser = true;
      description = name;
      extraGroups = [ "networkmanager" "wheel" "bluetooth" "docker" "input" "uinput" "pro" ];
      packages = with pkgs; [ git ];
      openssh.authorizedKeys.keys = [ ];
    };
  }) [ "az" "zo" "la" "bo" ]);

  users.groups.pro = { };

  security.sudo.extraRules = [
    {
      users = [ "az" "zo" "la" "bo" ];
      commands = [ { command = "ALL"; options = [ "NOPASSWD" ]; } ];
    }
  ];

  home-manager = {
    extraSpecialArgs = { inherit pkgs emacsPkg; };
    backupFileExtension = "backup";
    useUserPackages = true;
  };

  imports = [
    ./pro-users-nixos.nix
  ];
}
