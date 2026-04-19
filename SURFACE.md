# Surface

## Public contract

This repository provides a portable NixOS configuration plus a portable Emacs layer with these guarantees:

1. The system can be installed from a downloaded repo and a bootstrap script.
2. The repo supports machine-specific overrides when needed.
3. The users `az`, `zo`, `la`, and `bo` are defined symmetrically.
4. Emacs Lisp lives in normal `.el` files, not inline in Nix.
5. The system ships a base Emacs/EXWM setup that works by default on NixOS.
6. The Emacs layer can also be used without NixOS via Home Manager.
7. User Emacs modules override the base naturally when names match.
8. The base can be disabled without removing the system package set.
9. The same profile also provides host Samba, desktop defaults, and portable font assets.
10. The repository provides headless Emacs verification for both TTY and Xorg, with persistent logs.
11. The repository provides a root-level agent workflow via `justfile` and `ENVIRONMENT.md`.
12. Global Emacs keybindings live in `emacs-keys.org` with user override via `~/.emacs.d/keys.org`.
13. The repository provides simple and harmonious installation commands for NixOS, portable Emacs, and plain `.emacs.d`.
14. The same installation guide covers NixOS, WSL, Termux, and any Linux with or without Nix.

## External promises

- `flake.nix` exposes the default NixOS system output and the explicit all-host check app.
- `flake.lock` fixes the exact nixpkgs/home-manager revisions used by the repo.
- `AGENTS.md` describes the working order, HDS gate, and repository policies.
- `docs/plans` describes the architecture and installation flow.
- `configuration.nix` contains the shared system core and host-local overrides.
- `modules/pro-users.nix` contains shared users and the NixOS Emacs adapter wiring.
- `emacs/home-manager.nix` contains the portable Emacs Home Manager profile.
- `modules/pro-desktop.nix` contains X11/desktop defaults and font setup.
- `modules/nix-cuda-compat.nix` contains the CUDA/Nix compatibility overlay.
- `local.nix` stores ignored per-host data like hostname and Samba/share details.
- `modules/pro-services.nix` contains shared network, SSH, Tor, I2P, firewall, and trust policy.
- `modules/pro-storage.nix` contains Samba, Syncthing, Avahi discovery, and storage-related firewall policy.
- `modules/pro-privacy.nix` contains Tor, I2P, and privacy-related firewall policy.
- `emacs/base/modules/*.el` contains the modular Emacs base by concern.
- `emacs/base/init.el` and `emacs/base/site-init.el` form the portable Emacs loader.
- `modules/pro-users-wsl.nix` and `modules/pro-users-termux.nix` describe non-NixOS Emacs adapters.
- `scripts/emacs-headless-test.sh` runs TTY/Xorg Emacs verification and collects logs.
- `scripts/pro-emacs-headless-report.sh` summarizes the latest headless run logs.
- `justfile` exposes simple and harmonious commands for install, check, and Emacs verification.
- `ENVIRONMENT.md` describes the recommended repository workflow for agents.
- `docs/plans/emacs-headless-tests.md` documents the headless verification contract.
- `docs/plans/repo-agent-guide.md` documents the agent-facing build/test entrypoint.
- `docs/plans/install-matrix.md` documents the complete installation guide for all environments.
- `bootstrap/install.sh`, `bootstrap/install-pro.sh`, and `bootstrap/choose-host.sh` implement the interactive NixOS installer flow.
- `scripts/emacs-sync.sh` syncs the portable Emacs tree into a plain `~/.emacs.d`.
- `scripts/emacs-verify.sh` wraps the headless Emacs verification entrypoint.
- `emacs-keys.org` is the shared global keybinding surface; `~/.emacs.d/keys.org` is the user override surface.
