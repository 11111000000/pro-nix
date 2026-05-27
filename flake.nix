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
      };
      pkgs = import nixpkgs {
        inherit system;
        config = nixpkgsConfig;
      };
      pkgsOverlay = import nixpkgs {
        inherit system;
        config = nixpkgsConfig;
        overlays = [ (import ./nix/overlays/emacs-extra.nix) (import ./nix/overlays/opencode-stub.nix) (import ./nix/overlays/pi-acp.nix) ];
      };
      emacsPkg = pkgs.emacs30 or pkgs.emacs;
      piPkg = pi.packages.${system}.coding-agent;
      # Keep the Home Manager module reference so HM users still get the
      # opencode-bwrap sandbox wrapper. The overlay provides a real opencode
      # binary from npm (not a stub) so both direct CLI usage and bwrap work.
      opencodeBwrapModule = opencodeBwrap.homeManagerModules.default;
      pythonWithTextual = pkgs.python3.withPackages (ps: with ps; [ textual psutil ]);
      # Python environment for agent apps (coordinator/worker)
      pythonAgentEnv = pkgs.python3.withPackages (ps: with ps; [ flask requests ]);
      # Python environment for model-client (FastAPI + uvicorn)
      pythonModelEnv = pkgs.python3.withPackages (ps: with ps; [ fastapi uvicorn requests ]);

      # Global modules to apply to all hosts
      # Temporarily disable adb-udev global module to avoid etc.drv build permission issues.
      # If the nix-hermes input provides a NixOS module, enable it globally so
      # Hermes is available on all hosts (hosts may still opt-out).
      # Import the upstream pi NixOS module so its options are available.
      globalModules = [ pi.nixosModules.default ./modules/ssh-agent.nix ];

      mkHost = extraModules: nixpkgs.lib.nixosSystem {
        inherit system;
        # Use the overlayed pkgs so our opencode-stub overlay takes effect
        pkgs = pkgsOverlay;
        specialArgs = { inherit emacsPkg piPkg opencodeBwrapModule; };
        modules = [
          home-manager.nixosModules.home-manager
          ./configuration.nix
          ./nix/modules/searxng.nix
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
      mkVmHost = extraModules: nixpkgs.lib.nixosSystem {
        inherit system;
        pkgs = pkgsOverlay;
        specialArgs = { inherit emacsPkg piPkg opencodeBwrapModule; };
        modules = [
          home-manager.nixosModules.home-manager
          ./modules/packages-runtime.nix
          ./modules/tty-console.nix
          ./nix/modules/searxng.nix
        ] ++ extraModules;
      };

      # Deterministic opencode derivation used by apps and made available
      # via specialArgs to system modules for reproducible installs.
       # opencode_from_release removed

      # Expose nix-hermes overlay & modules if available. We don't enable
      # the service by default; hosts opt-in via modules in their host config.
       # hermes overlay/modules removed

      # Package the TUI sources into a small derivation and provide a
      # wrapper that uses a python interpreter with textual available.
      proNixTui = pkgs.stdenv.mkDerivation {
        pname = "pro-nix-tui";
        version = "0";
        src = ./.;
        buildInputs = [];
        nativeBuildInputs = [];
        dontBuild = true;
        installPhase = ''
          mkdir -p $out/bin $out/lib/pro-nix-tui
          cp -r ${./tui}/* $out/lib/pro-nix-tui/
          cat > $out/bin/pro-nix <<EOF
#!${pythonWithTextual}/bin/python3
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'lib', 'pro-nix-tui'))
exec(${pythonWithTextual}/bin/python3 if False else '${pythonWithTextual}/bin/python3')
EOF
          chmod +x $out/bin/pro-nix
        '';
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
        cf19-vm = import ./tests/vm/cf19-vm.nix { inherit (pkgs) testers; };
      };

      apps.${system} = {
        check-all = {
          type = "app";
          meta.description = "Build all machine configurations explicitly";
          program = toString (pkgs.writeShellScript "check-all-hosts" ''
            set -eu
            nix build .#nixosConfigurations.cf19.config.system.build.toplevel
            nix build .#nixosConfigurations.huawei.config.system.build.toplevel
            nix build .#nixosConfigurations.desktop.config.system.build.toplevel
          '');
        };

        # opencode app removed
        # Утилита: добавляем удобное приложение для запуска TUI (Textual pro-nix manager)
        pro-nix = {
          type = "app";
          # Create a tiny wrapper script in the store that calls the python
          # interpreter from a python-with-textual closure and points at the
          # app.py source in the flake. This avoids attempting to execute the
          # app during the python env build and keeps closures explicit.
          program = toString (pkgs.writeShellScript "pro-nix-tui" ''
            #!${pythonWithTextual}/bin/python3
            exec ${pythonWithTextual}/bin/python3 ${toString ./tui/app.py} "$@"
          '');
          meta = {
            description = "Запустить текстовый TUI менеджер pro-nix (Textual)";
          };
        };
        coordinator = {
          type = "app";
          program = toString (pkgs.writeShellScript "coordinator" ''
            #!${pythonAgentEnv}/bin/python3
            exec ${pythonAgentEnv}/bin/python3 ${toString ./apps/coordinator/coordinator.py} "$@"
          '');
          meta.description = "Запустить reference coordinator (dev)";
        };

        worker = {
          type = "app";
          program = toString (pkgs.writeShellScript "worker" ''
            #!${pythonAgentEnv}/bin/python3
            exec ${pythonAgentEnv}/bin/python3 ${toString ./apps/worker/worker.py} "$@"
          '');
          meta.description = "Запустить reference worker (dev)";
        };

        model-client = {
          type = "app";
          program = toString (pkgs.writeShellScript "model-client" ''
            #!${pythonModelEnv}/bin/python3
            exec ${pythonModelEnv}/bin/python3 ${toString ./apps/model-client/app.py} "$@"
          '');
          meta.description = "Запустить local model-client proxy (dev)";
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
          # Try overlay-provided packages when available (agent-shell, treemacs-icons-dired, eldoc-box)
          (if (builtins.hasAttr "emacsPackages" pkgsOverlay && builtins.hasAttr "agent-shell" pkgsOverlay.emacsPackages) then pkgsOverlay.emacsPackages.agent-shell else null)
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
