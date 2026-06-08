# Файл: автосгенерированная шапка — комментарии рефакторятся
{
  description = "Portable Pro NixOS Config";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-25.11";
    systems.url = "github:nix-systems/default";
    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    opencodeBwrap.url = "github:michalrus/opencode-bwrap-nix";
    opencodeBwrap.inputs.nixpkgs.follows = "nixpkgs";
    pi.url = "github:lukasl-dev/pi.nix";
    pi.inputs.nixpkgs.follows = "nixpkgs";
    pi.inputs.systems.follows = "systems";
    # Hermes agent (fork provided by user). Use SSH URL so private/forked repo works.
    # nix-hermes removed
  };

  outputs = inputs@{ self, nixpkgs, home-manager, opencodeBwrap, pi, ... }:
    let
      system = "x86_64-linux";
      lib = nixpkgs.lib;
      # Import nixpkgs. Also create a variant with the local emacs overlay
      # so we can optionally reference emacsPackages that the overlay exposes.
      nixpkgsConfig = {
        allowUnfree = true;
        rewriteURL = url:
          let
            githubProxy = builtins.getEnv "NIX_GITHUB_PROXY";
            rewrites = [
              { from = "https://astron.com/pub/file/"; to = "https://distfiles.macports.org/file/"; }
              { from = "https://astron.com/"; to = "https://distfiles.macports.org/"; }
              { from = "https://ftp.astron.com/pub/file/"; to = "https://distfiles.macports.org/file/"; }
              { from = "https://git.kernel.org/"; to = "https://mirrors.edge.kernel.org/"; }
              { from = "https://www.kernel.org/"; to = "https://mirrors.edge.kernel.org/"; }
              { from = "https://curl.haxx.se/"; to = "https://curl.se/"; }
            ];
            rewriteOnce = u: r:
              if lib.strings.hasPrefix r.from u then lib.strings.replaceStrings [ r.from ] [ r.to ] u else u;
            rewritten = lib.foldl' rewriteOnce url rewrites;
          in
            if githubProxy != "" && lib.strings.hasPrefix "https://github.com/" rewritten then
              githubProxy + rewritten
            else
              rewritten;
      };
      pkgs = import nixpkgs {
        inherit system;
        config = nixpkgsConfig;
      };
      pkgsOverlay = import nixpkgs {
        inherit system;
        config = nixpkgsConfig;
        overlays = [ (import ./nix/overlays/emacs-extra.nix) (import ./nix/overlays/opencode-stub.nix) (import ./nix/overlays/pi-acp.nix) (import ./nix/overlays/mirrors.nix) (import ./nix/overlays/github-proxy.nix) ];
      };
      emacsPkg = pkgs.emacs30 or pkgs.emacs;
      piPkg = pi.packages.${system}.coding-agent;
      # Keep the Home Manager module reference so HM users still get the
      # opencode-bwrap sandbox wrapper. The overlay provides a real opencode
      # binary from npm (not a stub) so both direct CLI usage and bwrap work.
      opencodeBwrapModule = opencodeBwrap.homeManagerModules.default;
      # Global modules to apply to all hosts
      # If the nix-hermes input provides a NixOS module, enable it globally so
      # Hermes is available on all hosts (hosts may still opt-out).
      # Import the upstream pi NixOS module so its options are available.
      globalModules = [ pi.nixosModules.default ./modules/ssh-agent.nix ];

      mkHost = extraModules: nixpkgs.lib.nixosSystem {
        inherit system;
        # Use the overlayed pkgs so our opencode-stub overlay takes effect
        pkgs = pkgsOverlay;
        specialArgs = { inherit emacsPkg piPkg opencodeBwrapModule searxngSecretKey; };
        modules = [
          home-manager.nixosModules.home-manager
          ./configuration.nix
          ./modules/searxng.nix
          # NOTE: the treesitter grammars derivation is exposed at
          # the flake top level (treesitterGrammars). Do NOT import
          # it here as a NixOS module — that would return a derivation
          # (a store path / string) where a module attribute set is
          # expected and causes evaluation errors.
          # user-templates is imported directly from configuration.nix to avoid
          # circular evaluation dependencies
        ] ++ globalModules ++ extraModules;
      };

      # Minimal VM host for testing without full configuration.nix (which brings in pro-peer, etc)
      searxngSecretKey = if builtins.pathExists ./secrets/searxng-key
                         then builtins.readFile ./secrets/searxng-key
                         else "changeme-replace-with-secure-random";

      mkVmHost = extraModules: nixpkgs.lib.nixosSystem {
        inherit system;
        pkgs = pkgsOverlay;
        specialArgs = { inherit emacsPkg piPkg opencodeBwrapModule searxngSecretKey; };
        modules = [
          home-manager.nixosModules.home-manager
          ./modules/packages-runtime.nix
          ./modules/tty-console.nix
          ./modules/searxng.nix
        ] ++ extraModules;
      };

      hosts = {
        cf19 = mkHost [ ./hosts/cf19/configuration.nix ./hosts/cf19/composition.nix ];
        huawei = mkHost [ ./hosts/huawei/configuration.nix ./hosts/huawei/composition.nix ];
        desktop = mkHost [ ./hosts/desktop/configuration.nix ./hosts/desktop/composition.nix ];
        vm = mkVmHost [ ./hosts/vm/configuration.nix ./hosts/vm/composition.nix ];
      };
    in {
      nixosConfigurations = hosts;

      checks.${system} = {
        default = hosts.huawei.config.system.build.toplevel;
        # NixOS VM tests for activation verification
        huawei-boot = import ./tests/vm/huawei-boot.nix {
          inherit (pkgs) testers;
          # pass the home-manager module (not the input set) so the test
          # can import it as a NixOS module. Previously we attempted to
          # inherit `home-manager` from `pkgs` which produced the wrong
          # value/type and caused flake evaluation errors in the VM test.
          home-manager = home-manager.nixosModules.home-manager;
          piModule = pi.nixosModules.default;
        };
        basic-activation-test = import ./tests/vm/test-basic-activation.nix { inherit (pkgs) testers; };
        cf19-switch-dbus-regression = import ./tests/vm/cf19-switch-dbus-regression.nix { inherit (pkgs) testers; };
      };

      apps.${system} = {
        check-all = {
          type = "app";
          meta.description = "Build all machine configurations explicitly";
          program = toString (pkgs.writeShellScript "check-all-hosts" ''
            set -eu
            # Используем git+file://...?submodules=1 — path: и . НЕ включают
            # submodules в captured source (см. AGENTS.md §6a).
            FLAKE="git+file://$PWD?submodules=1"
            nix build "$FLAKE#nixosConfigurations.cf19.config.system.build.toplevel"
            nix build "$FLAKE#nixosConfigurations.huawei.config.system.build.toplevel"
            nix build "$FLAKE#nixosConfigurations.desktop.config.system.build.toplevel"
          '');
        };

      };

      devShells.${system}.default = let
        rawPkgs = [
          pkgs.emacsPackages.vertico pkgs.emacsPackages.consult pkgs.emacsPackages.orderless
          pkgs.emacsPackages.marginalia pkgs.emacsPackages.gptel pkgs.emacsPackages.consult-dash
          pkgs.emacsPackages.consult-eglot pkgs.emacsPackages.consult-yasnippet pkgs.emacsPackages.corfu
          pkgs.emacsPackages.cape pkgs.emacsPackages.kind-icon pkgs.emacsPackages.avy
          pkgs.emacsPackages.expand-region pkgs.emacsPackages.yasnippet pkgs.emacsPackages.projectile
          pkgs.emacsPackages.treemacs pkgs.emacsPackages.vterm pkgs.emacsPackages.ace-window pkgs.emacsPackages.embark
          pkgs.emacsPackages.dash-docs pkgs.emacsPackages.embark-consult
          # Try overlay-provided packages when available (agent-shell, acp, treemacs-icons-dired, eldoc-box)
          (if (builtins.hasAttr "emacsPackages" pkgsOverlay && builtins.hasAttr "agent-shell" pkgsOverlay.emacsPackages) then pkgsOverlay.emacsPackages.agent-shell else null)
          (if (builtins.hasAttr "emacsPackages" pkgsOverlay && builtins.hasAttr "agent-shell-hud" pkgsOverlay.emacsPackages) then pkgsOverlay.emacsPackages.agent-shell-hud else null)
          (if (builtins.hasAttr "emacsPackages" pkgsOverlay && builtins.hasAttr "acp" pkgsOverlay.emacsPackages) then pkgsOverlay.emacsPackages.acp else null)
          (if (builtins.hasAttr "emacsPackages" pkgsOverlay && builtins.hasAttr "telega" pkgsOverlay.emacsPackages) then pkgsOverlay.emacsPackages.telega else null)
          (if (builtins.hasAttr "emacsPackages" pkgsOverlay && builtins.hasAttr "treemacs-icons-dired" pkgsOverlay.emacsPackages) then pkgsOverlay.emacsPackages."treemacs-icons-dired" else null)
          (if (builtins.hasAttr "emacsPackages" pkgsOverlay && builtins.hasAttr "eldoc-box" pkgsOverlay.emacsPackages) then pkgsOverlay.emacsPackages.eldoc-box else null)
        ];
        presentPkgs = builtins.filter (p: p != null) rawPkgs;
      in pkgs.mkShell {
        name = "pro-nix-dev";
        # Ensure overlay-provided emacs package derivations are present in the shell
        # so their /share/emacs/site-lisp paths exist for the emacs wrapper.
        buildInputs = [ emacsPkg pkgs.ripgrep pkgs.fd pkgs.findutils pkgs.stress-ng pkgs.fio pkgs.powertop pkgs.iotop pkgs.lm_sensors pkgs.time pkgs.shellcheck pkgs.direnv pkgs.gh ] ++ presentPkgs;
        shellHook = let
          flags = lib.concatStringsSep " " (map (p: "-L " + p + "/share/emacs/site-lisp") presentPkgs);
        in ''
          echo "Entering pro-nix devshell with Emacs available"
          mkdir -p "$PWD/.pro-emacs-wrapper"
          EMACS_BIN="${toString emacsPkg}/bin/emacs"
          cat > "$PWD/.pro-emacs-wrapper/emacs-pro" <<SH
#!/bin/sh
EMACS_BIN="${toString emacsPkg}/bin/emacs"
exec "$EMACS_BIN" -Q ${flags} "$@"
SH
          chmod +x "$PWD/.pro-emacs-wrapper/emacs-pro"
          export PATH="$PWD/.pro-emacs-wrapper:$PATH"
          echo "Created emacs wrapper at $PWD/.pro-emacs-wrapper/emacs-pro"
        '';
      };
      # Expose the treesitter-grammars derivation in the flake for easy reference
      treesitterGrammars = import ./nix/treesitter-grammars.nix { inherit pkgs; };
    };

}
