{
  description = "Portable Pro NixOS Config";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-24.05";
    home-manager.url = "github:nix-community/home-manager/release-24.05";
  };

  outputs = inputs@{ nixpkgs, ... }:
    let
      system = "x86_64-linux";
      lib = nixpkgs.lib;
      pkgs = import nixpkgs { inherit system; };

      mkHost = extraModules: lib.nixosSystem {
        inherit system;
        modules = [
          inputs.home-manager.nixosModules.home-manager
          ./configuration.nix
        ] ++ extraModules;
      };

      hosts = {
        thinkpad = mkHost [ ./hosts/thinkpad/configuration.nix ];
        desktop = mkHost [ ./hosts/desktop/configuration.nix ];
        cf19 = mkHost [ ./hosts/cf19/configuration.nix ];
      };
    in {
      nixosConfigurations = {
        default = hosts.thinkpad;
      };

      checks.${system}.default = hosts.thinkpad.config.system.build.toplevel;

      proConfigurations = hosts;

      apps.${system}.check-all = {
        type = "app";
        program = toString (pkgs.writeShellScript "check-all-hosts" ''
          set -eu
          nix build .#proConfigurations.default.config.system.build.toplevel
          nix build .#proConfigurations.desktop.config.system.build.toplevel
          nix build .#proConfigurations.cf19.config.system.build.toplevel
        '');
      };
    };
}
