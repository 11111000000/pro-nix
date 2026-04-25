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
      # Import nixpkgs (do not apply local emacs overlay in devshell runs to
      # avoid incompatibilities in CI images). Overlays that add custom
      # emacs packaging can be re-enabled when maintenance updates them.
      pkgs = import nixpkgs { inherit system; };
      emacsPkg = pkgs.emacs30 or pkgs.emacs;
      pythonWithTextual = pkgs.python3.withPackages (ps: with ps; [ textual psutil ]);
      # Python environment for agent apps (coordinator/worker)
      pythonAgentEnv = pkgs.python3.withPackages (ps: with ps; [ flask requests ]);
      # Python environment for model-client (FastAPI + uvicorn)
      pythonModelEnv = pkgs.python3.withPackages (ps: with ps; [ fastapi uvicorn requests ]);

      # Global modules to apply to all hosts
      # Temporarily disable adb-udev global module to avoid etc.drv build permission issues.
      globalModules = [  ];

      mkHost = extraModules: nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit emacsPkg opencode_from_release; };
        modules = [
          home-manager.nixosModules.home-manager
          ./configuration.nix
        ./nixos/modules/opencode-config.nix
        # user-templates is imported directly from configuration.nix to avoid
        # circular evaluation dependencies
        ] ++ globalModules ++ extraModules;
      };

      # Deterministic opencode derivation used by apps and made available
      # via specialArgs to system modules for reproducible installs.
      opencode_from_release = pkgs.stdenv.mkDerivation rec {
        pname = "opencode";
        version = "1.14.19";
        src = pkgs.fetchurl {
          url = "https://github.com/anomalyco/opencode/releases/download/v1.14.19/opencode-linux-x64.tar.gz";
          sha256 = "8cb11723ce0ec82e2b6ff9a2356b12c2f4c4a95a087ba0a3004b19f167951440";
        };
        nativeBuildInputs = [ pkgs.patchelf ];
        unpackPhase = ''
          mkdir -p $TMPDIR/unpack
          tar xzf "$src" -C $TMPDIR/unpack
        '';
        installPhase = ''
          mkdir -p $out/bin
          cp $TMPDIR/unpack/opencode $out/bin/
          chmod +x $out/bin/opencode
          # Ensure the binary uses the Nix store's dynamic loader so it can
          # run on NixOS without the FHS compatibility layer. Some upstream
          # releases expect /lib64/ld-linux-x86-64.so.2 and will fail with
          # the "stub-ld" message; force the interpreter to the Nix glibc.
          if [ -x "$out/bin/opencode" ]; then
            patchelf --set-interpreter "${pkgs.glibc}/lib/ld-linux-x86-64.so.2" "$out/bin/opencode" || true
            # set a conservative rpath so the loader can find libdl/libc
            patchelf --set-rpath "${pkgs.glibc}/lib" "$out/bin/opencode" || true
          fi
        '';
      };

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
        cf19 = mkHost [ ./hosts/cf19/configuration.nix ];
        huawei = mkHost [ ./hosts/huawei/configuration.nix ];
      };
    in {
      nixosConfigurations = hosts;

      checks.${system}.default = hosts.huawei.config.system.build.toplevel;

      apps.${system} = {
        check-all = {
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
        opencode-release = {
          type = "app";
          # Forward all CLI arguments to the bundled opencode binary so callers
          # can use the flake app as a transparent proxy (eg. `nix run .#opencode-release -- <args>`).
          program = toString (pkgs.writeShellScriptBin "opencode-release" ''
            set -eu
            exec ${toString opencode_from_release}/bin/opencode "$@"
          '');
          meta.description = "Reproducible opencode binary (release)";
        };

        # (opencode-store removed — using system-packages.nix opencodeBin instead)
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

        devShells.${system}.default = pkgs.mkShell {
        name = "pro-nix-dev";
        buildInputs = [ emacsPkg pkgs.ripgrep pkgs.fd pkgs.findutils pkgs.stress-ng pkgs.fio pkgs.powertop pkgs.iotop pkgs.lm_sensors pkgs.time pkgs.shellcheck pkgs.direnv pkgs.gh ];
        shellHook = let
          flags = lib.concatStringsSep " " (map (p: "-L " + p + "/share/emacs/site-lisp") [
            pkgs.emacsPackages.vertico pkgs.emacsPackages.consult pkgs.emacsPackages.orderless
            pkgs.emacsPackages.marginalia pkgs.emacsPackages.gptel pkgs.emacsPackages.consult-dash
            pkgs.emacsPackages.consult-eglot pkgs.emacsPackages.consult-yasnippet pkgs.emacsPackages.corfu
            pkgs.emacsPackages.cape pkgs.emacsPackages.kind-icon pkgs.emacsPackages.avy
            pkgs.emacsPackages.expand-region pkgs.emacsPackages.yasnippet pkgs.emacsPackages.projectile
            pkgs.emacsPackages.treemacs pkgs.emacsPackages.vterm pkgs.emacsPackages.ace-window pkgs.emacsPackages.embark
            # Additional packages to emulate the Nix-provided Emacs profile
            pkgs.emacsPackages.dash-docs pkgs.emacsPackages.agent-shell pkgs.emacsPackages.treemacs-icons-dired
            pkgs.emacsPackages.all-the-icons pkgs.emacsPackages.nerd-icons pkgs.emacsPackages.embark-consult
          ]);
        in ''
          echo "Entering pro-nix devshell with Emacs available"
          WRAP_DIR="${toString ./.}/.pro-emacs-wrapper"
          mkdir -p "$WRAP_DIR"
          EMACS_BIN="${toString emacsPkg}/bin/emacs"
          cat > "$WRAP_DIR/emacs-pro" <<SH
#!/bin/sh
EMACS_BIN="${toString emacsPkg}/bin/emacs"
exec "$EMACS_BIN" -Q ${flags} "$@"
SH
          chmod +x "$WRAP_DIR/emacs-pro"
          export PATH="$WRAP_DIR:$PATH"
          echo "Created emacs wrapper at $WRAP_DIR/emacs-pro"
        '';
      };
    };
}
