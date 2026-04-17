# Surface

## Public contract

This repository provides a portable NixOS configuration called `pro` with these guarantees:

1. The system can be installed from a downloaded repo and a bootstrap script.
2. The repo supports multiple hardware profiles.
3. The users `az`, `zoya`, `lada`, and `boris` are defined symmetrically.
4. Emacs Lisp lives in normal `.el` files, not inline in Nix.
5. The system ships a base Emacs/EXWM setup that works by default.
6. User Emacs modules override the base naturally when names match.
7. The base can be disabled without removing the system package set.
8. The same profile also provides host Samba, desktop defaults, and portable font assets.

## External promises

- `flake.nix` exposes the `pro` system output.
- `docs/plans` describes the architecture and installation flow.
- `configuration.nix` contains the shared system core and host-local overrides.
- `modules/pro-users.nix` contains shared users, Home Manager, and the Emacs base wiring.
- `modules/pro-desktop.nix` contains X11/desktop defaults and font setup.
- `modules/nix-cuda-compat.nix` contains the CUDA/Nix compatibility overlay.
- `local.nix` stores ignored per-host data like hostname and Samba/share details.
