## HDS Rules

1. Surface first: record user-visible contract here before changing implementation.
2. Text is test: if a rule matters, write it in text and keep a check for it.
3. One file, one concern: keep modules small and single-purpose.
4. Prefer explicit loading order over hidden coupling.
5. Use Org as the source of truth for keybindings and other declarative surfaces.

## Public Contract

Репозиторий предоставляет переносимую NixOS конфигурацию и модульный Emacs‑слой с следующими гарантиями:

1. Система может быть установлена из репозитория с помощью bootstrap-скрипта.
2. Поддерживаются машинно-специфичные переопределения конфигурации.
3. Emacs Lisp хранится в обычных `.el` файлах, а не инлайном в Nix.
4. По умолчанию поставляется базовый Emacs/EXWM профиль, работоспособный на NixOS.
5. Emacs‑слой может использоваться без NixOS через Home Manager.
6. Пользовательские Emacs‑модули переопределяют базовые при совпадении имён.
7. Базовый профиль можно отключить, не удаляя набор системных пакетов.
8. Репозиторий предоставляет headless‑проверки Emacs (TTY и Xorg) и логи выполнения.
9. Есть стандартизованный workflow агентов (`justfile`, `ENVIRONMENT.md`).
10. Глобальные биндинги Emacs находятся в `emacs-keys.org`; локальные переопределения — в `~/.emacs.d/keys.org`.
11. Репозиторий предлагает простые команды для установки: NixOS, portable Emacs и plain `~/.emacs.d`.

## Surface Items

- Name: Healthcheck
  Stability: [FROZEN]
  Spec: The repository exposes a headless Emacs verification script that completes successfully on the host: `./scripts/emacs-headless-test.sh`.
  Proof: tests/contract/test_surface_health.spec

- Name: InstallMethods
  Stability: [FLUID]
  Spec: Installation can be performed via `bootstrap/install.sh`, `bootstrap/install-pro.sh`, or NixOS activation.
  Proof: -

- Name: SystemRuntimePaths
  Stability: [FLUID]
  Spec: The default system profile exposes core interactive tools on the runtime PATH, including `bash` and `ssh` under `/run/current-system/sw/bin/`.
  Proof: tests/contract/test_system_runtime_paths.spec

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
- `system-packages.nix` contains the workspace package set and the system agent tools available immediately on PATH (`goose`, `aider`, `opencode`, and `pipx`).
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
- `docs/plans/agent-tooling.md` documents the supported open-source agent matrix and install policy.
- `docs/plans/install-matrix.md` documents the complete installation guide for all environments.
- `templates/` contains user configuration templates that are deployed by the NixOS policy and copied into user homes when missing.
- The template contract is: repo-owned files under `templates/` are installed into `/etc/skel/pro-templates` on every host, then Home Manager copies them into user homes only if the target file is missing.
- `bootstrap/install.sh`, `bootstrap/install-pro.sh`, and `bootstrap/choose-host.sh` implement the interactive NixOS installer flow.
- `scripts/emacs-sync.sh` syncs the portable Emacs tree into a plain `~/.emacs.d`.
- `scripts/emacs-verify.sh` wraps the headless Emacs verification entrypoint.
- `.gitignore` excludes generated `*.elc`/`*.eln` and other transient files.
- `emacs-keys.org` is the shared global keybinding surface; `~/.emacs.d/keys.org` is the user override surface.

## Soft Reload (Modules) Surface

- Name: Soft Reload (Modules)
  Stability: [FLUID]
  Spec: Reload individual pro-nix Emacs modules at runtime without restarting Emacs. Modules must be idempotent and expose migrate/reset hooks for complex state. Public API: `pro/reload-module`, `pro/reload-all-modules`.
  Proof: ERT + manual: `(pro/reload-module 'terminals)`, `(pro/reload-all-modules)`

## Keybindings Surface

- Name: Keybindings Surface
  Stability: [FLUID]
  Spec: Centralized global keybinding surface stored in `emacs-keys.org`. Modules publish suggested keys via `pro/register-module-keys`. Suggestions can be auto-merged into `emacs-keys.org` for review. Loader applies system → user overrides and handles pending bindings for late-defined commands.
  Proof: commands: `scripts/generate-key-suggestions.py`, `scripts/apply-key-suggestions.py`, `pro/keys-reload` (`M-x pro/keys-reload`)

## Package Update (MELPA) Surface

- Name: Package Update (MELPA)
  Stability: [FLUID]
  Spec: Background batch updater for ELPA/MELPA that refreshes archives and installs/updates packages without blocking interactive Emacs. Public API: `pro/update-melpa-in-background` (starts background batch process running `scripts/melpa-update.el`).
  Proof: run `M-x pro/update-melpa-in-background` and inspect buffer `*pro-melpa-update*`; `scripts/melpa-update.el`

## Nix Site-Lisp Path Surface

- Name: Nix Site-Lisp Path Surface
  Stability: [FLUID]
  Spec: Generator (`scripts/nix-update-emacs-paths.sh`) discovers `/nix/store/*/share/emacs/site-lisp` and writes `emacs/base/nix-emacs-paths.el`. Emacs API `pro/nix-generate-and-refresh-paths` loads paths and refreshes `load-path` at runtime. Note: native C extensions still require restart.
  Proof: `./scripts/nix-update-emacs-paths.sh`; `M-x pro/nix-generate-and-refresh-paths`

## Session Save / Soft Restart Surface

- Name: Session Save / Soft Restart
  Stability: [FLUID]
  Spec: Save minimal session state (open files, points, window-state) and restore after restart. API: `pro/session-save`, `pro/session-restore`, `pro/session-save-and-restart-emacs`. Designed to support smooth restart when native libs changed.
  Proof: `M-x pro/session-save` RET; `M-x pro/session-restore` RET; `M-x pro/session-save-and-restart-emacs`

Notes:
- All surfaces are conservative: GUI-only features are guarded by `display-graphic-p` and Nix/native upgrades that touch C-extensions must be followed by a restart (session helper provided).
- For any surface marked [FROZEN/FLUID] see HOLO.md for Change Gate and proof commands.

## Pro‑peer: Discovery & Key Sync

- Name: Pro-peer (Discovery & Key Sync)
  Stability: [FLUID]
  Spec: Peer discovery and authorized-keys distribution service used to deploy per-host encrypted artifacts and synchronize authorized_keys. Managed via `modules/pro-peer.nix` and runtime scripts. Supports Yggdrasil/WireGuard helpers and optional Tor hidden-service for SSH.
  Proof: smoke scripts: `scripts/pro-peer-sync-keys.sh --help` and `scripts/pro-peer-master.sh --help`; module presence `modules/pro-peer.nix`.

## Samba Automount & Creds Distribution

- Name: Samba Automount / Creds Distribution
  Stability: [FLUID]
  Spec: Automount and discovery helpers for Samba mounts with an operator-managed secure credentials distribution pattern (encrypted creds deployed via pro-peer workflow). Public scripts: `scripts/mount-smb.sh` and templates/system units in `modules/`.
  Proof: docs and smoke scripts: `docs/plans/smb-discovery-and-mount.md`, `scripts/mount-smb.sh --help`.

## proctl CLI / TUI

- Name: proctl CLI / TUI
  Stability: [FLUID]
  Spec: Command-line/TUI control surface for repository operations described by `tui/proctl/spec.md`. Exposes armable operator commands (push, sync, diagnostics).
  Proof: `tui/proctl/spec.md`, `scripts/test-opencode-launch.sh`.

## Provided Emacs Packages / Decisions

- Name: Provided Emacs Packages
  Stability: [FLUID]
  Spec: The repository provides a curated set of Emacs packages via Nix (provisioned packages) and documents decisions about package ownership (Nix vs MELPA) in `docs/decisions/emacs-packages-decisions.md`.
  Proof: generation script `scripts/generate-provided-packages.el` and decision doc `docs/decisions/emacs-packages-decisions.md`.
