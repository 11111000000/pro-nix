# Файл: автосгенерированная шапка — комментарии рефакторятся
{
  description = "Portable Pro NixOS Config";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-25.11";
    home-manager.url = "github:nix-community/home-manager/release-25.11";
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

      # Add a reproducible opencode package entry that fetches the official
      # release tarball and exposes it as an app for testing/CI. This gives a
      # deterministic path for environments where npx can't reach the registry.
      apps.${system}.opencode-release = {
        type = "app";
        program = toString (pkgs.writeShellScript "opencode-release" ''
          set -eu
          OUT="$TMPDIR/opencode-bin"
          mkdir -p "$OUT"
          URL="https://github.com/anomalyco/opencode/releases/latest/download/opencode-linux-x64.tar.gz"
          curl -fsSL "$URL" | tar xz -C "$OUT"
          exec "$OUT/opencode" --version
        '');
        meta.description = "Smoke-run the official opencode linux-x64 release";
      };
    # Утилита: добавляем удобное приложение для запуска TUI (Textual pro-nix manager)
      apps.${system}.pro-nix = {
        type = "app";
        program = toString (pkgs.writeShellScript "pro-nix-tui" ''
          set -eu
          # Run the Textual TUI from the repo
          python3 ./tui/app.py
        '');
        meta = {
          description = "Запустить текстовый TUI менеджер pro-nix (Textual)";
        };
      };
    };
}
