# Surface

## Public contract

This repository provides a portable NixOS configuration called `pro` with these guarantees:

1. The system can be installed from a downloaded repo and a bootstrap script.
2. The repo supports machine-specific overrides when needed.
3. The users `az`, `zoya`, `lada`, and `boris` are defined symmetrically.
4. Emacs Lisp lives in normal `.el` files, not inline in Nix.
5. The system ships a base Emacs/EXWM setup that works by default.
6. User Emacs modules override the base naturally when names match.
7. The base can be disabled without removing the system package set.
8. The same profile also provides host Samba, desktop defaults, and portable font assets.
9. The repository provides headless Emacs verification for both TTY and Xorg, with persistent logs.
10. The repository provides a root-level agent workflow via `justfile` and `ENVIRONMENT.md`.
11. Global Emacs keybindings live in `emacs-keys.org` with user override via `~/.emacs.d/keys.org`.

## External promises

- `flake.nix` exposes the `pro` system output.
- `AGENTS.md` describes the working order, HDS gate, and repository policies.
- `docs/plans` describes the architecture and installation flow.
- `configuration.nix` contains the shared system core and host-local overrides.
- `modules/pro-users.nix` contains shared users, Home Manager, and the Emacs base wiring.
- `modules/pro-desktop.nix` contains X11/desktop defaults and font setup.
- `modules/nix-cuda-compat.nix` contains the CUDA/Nix compatibility overlay.
- `local.nix` stores ignored per-host data like hostname and Samba/share details.
- `modules/pro-services.nix` contains shared network, SSH, Tor, I2P, firewall, and trust policy.
- `modules/pro-storage.nix` contains Samba, Syncthing, Avahi discovery, and storage-related firewall policy.
- `modules/pro-privacy.nix` contains Tor, I2P, and privacy-related firewall policy.
- `emacs/base/modules/*.el` contains the modular Emacs base by concern.
- `scripts/emacs-headless-test.sh` runs TTY/Xorg Emacs verification and collects logs.
- `scripts/pro-emacs-headless-report.sh` summarizes the latest headless run logs.
- `justfile` exposes the standard build/test/headless commands for agents.
- `ENVIRONMENT.md` describes the recommended repository workflow for agents.
- `docs/plans/emacs-headless-tests.md` documents the headless verification contract.
- `docs/plans/repo-agent-guide.md` documents the agent-facing build/test entrypoint.
- `emacs-keys.org` is the shared global keybinding surface; `~/.emacs.d/keys.org` is the user override surface.
