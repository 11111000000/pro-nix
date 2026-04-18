{
  description = "Portable Pro NixOS Config";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-24.05";
    utils.url = "github:numtide/flake-utils";
  };

  outputs = inputs@{ nixpkgs, utils, ... }:
    utils.lib.eachSystem [ "x86_64-linux" ] (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in {
        nixosConfigurations = {
          # Для каждой машины — отдельный профиль
          thinkpad = inputs.nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [
              ./configuration.nix
              ./hosts/thinkpad/configuration.nix
            ];
          };

          desktop = inputs.nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [
              ./configuration.nix
              ./hosts/desktop/configuration.nix
            ];
          };

          cf19 = inputs.nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [
              ./configuration.nix
              ./hosts/cf19/configuration.nix
            ];
          };

          # Краткий алиас
          default = inputs.nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [ ./configuration.nix ];
          };
        };
      }
    );
}