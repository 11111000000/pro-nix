{
  description = "Portable Pro NixOS Config";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-24.05";
    home-manager.url = "github:nix-community/home-manager/release-24.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux";
      lib = nixpkgs.lib;
      pkgs = import nixpkgs { inherit system; };
      emacsPkg = pkgs.emacs30 or pkgs.emacs;

      mkHost = extraModules: nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit emacsPkg; };
        modules = [
          home-manager.nixosModules.home-manager
          ./configuration.nix
        ] ++ extraModules;
      };

      hosts = {
        cf19 = mkHost [ ./hosts/cf19/configuration.nix ];
        huawei = mkHost [ ./hosts/huawei/configuration.nix ];
      };
    in {
      nixosConfigurations = hosts;

      checks.${system}.default = hosts.huawei.config.system.build.toplevel;

      apps.${system}.check-all = {
        type = "app";
        meta.description = "Build all machine configurations explicitly";
        program = toString (pkgs.writeShellScript "check-all-hosts" ''
          set -eu
          nix build .#nixosConfigurations.cf19.config.system.build.toplevel
          nix build .#nixosConfigurations.huawei.config.system.build.toplevel
        '');
      };
    };
}
