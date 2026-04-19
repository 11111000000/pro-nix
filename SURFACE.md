## HDS Rules

1. Surface first: record user-visible contract here before changing implementation.
2. Text is test: if a rule matters, write it in text and keep a check for it.
3. One file, one concern: keep modules small and single-purpose.
4. Prefer explicit loading order over hidden coupling.
5. Use Org as the source of truth for keybindings and other declarative surfaces.

## Public Contract

This repository provides a portable NixOS configuration plus a portable Emacs layer with these guarantees:

1. The system can be installed from a downloaded repo and a bootstrap script.
2. The repo supports machine-specific overrides when needed.
3. Emacs Lisp lives in normal `.el` files, not inline in Nix.
4. The system ships a base Emacs/EXWM setup that works by default on NixOS.
5. The Emacs layer can also be used without NixOS via Home Manager.
6. User Emacs modules override the base naturally when names match.
7. The base can be disabled without removing the system package set.
8. The repository provides headless Emacs verification for both TTY and Xorg, with persistent logs.
9. The repository provides a root-level agent workflow via `justfile` and `ENVIRONMENT.md`.
10. Global Emacs keybindings live in `emacs-keys.org` with user override via `~/.emacs.d/keys.org`.
11. The repository provides simple and harmonious installation commands for NixOS, portable Emacs, and plain `.emacs.d`.

## Emacs Lisp Style

1. Keep functions small and named by role, not by mechanism.
2. Prefer explicit contracts over clever control flow.
3. Use `use-package` for external packages and plain `defun`/`setq` for local policy.
4. Avoid hidden dependencies between modules; declare load order when it matters.
5. When a rule must survive LLM generation, write it as text and make it checkable.

## Keybinding Interface

1. Define keybindings in `emacs-keys.org` (org-mode).
2. Compile to Emacs Lisp with `org-babel-execute:org`.
3. Put overrides in `~/.emacs.d/keys.org` with the `:org` prefix.
4. Apply changes with `just install-emacs`.

> Keybindings compile to `~/.emacs.d/keys.el` and load automatically.

## External Promises

- `flake.nix` exposes the default NixOS system output and the explicit all-host check app.
- `flake.lock` fixes the exact nixpkgs/home-manager revisions used by the repo.
- `AGENTS.md` describes the working order, HDS gate, and repository policies.
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
- `emacs/base/modules/ai.el` loads AI provider policy and model defaults from `emacs/base/modules/ai-models.json` with user override via `~/.config/emacs/ai-models.json`.
- `emacs/base/init.el` and `emacs/base/site-init.el` form the portable Emacs loader.
- `modules/pro-users-wsl.nix` and `modules/pro-users-termux.nix` describe non-NixOS Emacs adapters.
- `scripts/emacs-headless-test.sh` runs TTY/Xorg Emacs verification, executes headless ERT tests, and collects logs.
- `scripts/test-emacs-headless.sh` runs the disposable-home headless test suite.
- `scripts/parse-emacs-logs.sh` summarizes the latest headless run logs.
- `scripts/pro-emacs-headless-report.sh` summarizes the latest headless run logs.
- `justfile` exposes simple and harmonious commands for install, check, and Emacs verification.
- `ENVIRONMENT.md` describes the recommended repository workflow for agents.
- `docs/plans/emacs-headless-tests.md` documents the headless verification contract.
- `docs/plans/emacs-headless-changelog.md` records the headless Emacs test and log workflow changes.
- `docs/plans/repo-agent-guide.md` documents the agent-facing build/test entrypoint.
- `docs/plans/install-matrix.md` documents the complete installation guide for all environments.
- `bootstrap/install.sh`, `bootstrap/install-pro.sh`, and `bootstrap/choose-host.sh` implement the interactive NixOS installer flow.
- `scripts/emacs-sync.sh` syncs the portable Emacs tree into a plain `~/.emacs.d`.
- `scripts/emacs-verify.sh` wraps the headless Emacs verification entrypoint.
- `.gitignore` excludes generated `*.elc`/`*.eln` and other transient files.
- `emacs-keys.org` is the shared global keybinding surface; `~/.emacs.d/keys.org` is the user override surface.
