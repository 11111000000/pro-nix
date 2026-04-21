Pro‑Nix — portable NixOS configs and ops tooling
===============================================

Purpose
-------
Pro‑Nix provides a portable, modular collection of NixOS configurations, an
Emacs layer and small operational tooling (TUI, CLI, scripts) aimed at
reproducible host provisioning, secure peer key management and agent‑driven
workflows.

Status
------
- Actively developed prototype with production‑grade modules and many
  operational notes in docs/. Some parts are experimental (TUI prototype,
  agent integrations).

Quick start
-----------
Requirements
- Nix with flakes enabled
- sudo/root to run `nixos-rebuild` on target hosts
- Python 3.10+ for the TUI prototype

Run the TUI (prototype)
1. From repository root:

   python3 ./tui/app.py

2. Alternatively, with flakes:

   nix run .#pro-nix

Apply a host configuration (example for host `cf19`)

1. Choose the host entry under hosts/ (for example `cf19`).
2. On the host run:

   sudo nixos-rebuild switch --flake .#cf19

If you use pro-peer (centralized SSH keys)
- Operator must provide `/etc/pro-peer/authorized_keys.gpg` to the host.
  See docs/plans/pro-peer-hardening-plan.md for details and hardening steps.

Repository layout (short)
- flake.nix, flake.lock — flake entry point and lockfile
- hosts/ — per‑host NixOS configurations (examples: cf19, huawei)
- modules/ — reusable NixOS modules (pro-peer, pro-storage, pro-desktop, pro-users, etc.)
- tui/ — Textual prototype TUI (Python). Contains pyproject.toml and app entrypoint
- proctl/ — CLI adapter used by TUI and Emacs; communicates using JSON
- scripts/ — operational scripts and diagnostics (samba diagnostics, emacs headless tests, nix helpers)
- conf/ — configuration templates (X, GTK, qt, etc.)
- docs/ — plans, specs and operational notes (important reference for usage and hardening)

Key features
- Modular NixOS modules focused on reproducibility and hardening
- pro-peer: centralized peer key distribution and services (Avahi, sync helpers)
- Emacs layer and agent tooling: integration points and headless Emacs verification
- TUI/CLI utilities for onboarding, key sync and diagnostics

Security and privileges
- Dangerous or destructive operations default to dry‑run / preview mode in the UI.
- Executing privileged actions requires explicit confirmation and elevation
  (sudo/pkexec). Actions are logged under `~/.local/share/pro-nix/actions.log`.

Development
- Python/TUI
  - Use a virtualenv or your system Python. Entry point: `tui/app.py` or `nix run .#pro-nix`.
- Nix
  - Use flakes: `nix flake show` and `nix build` / `nix run` as needed.
- Tests and verification
  - There are headless Emacs verification scripts and small E2E helpers under scripts/.

Important docs
- docs/plans/pro-peer-hardening-plan.md — pro-peer setup and operator instructions
- docs/ops/samba-hardening.md — Samba recommendations
- docs/agents.md and docs/plans/agent-tooling.md — agent integration and usage
- HOLO.md — architectural notes
- CHANGELOG.md — release notes and history

Contributing
- Open issues and pull requests are welcome. Prefer small, focused changes.
- Follow repository conventions in AGENTS.md and SURFACE.md for larger design decisions.

License
- No LICENSE file detected in repo root. If this should be public, add a LICENSE
  file with the desired terms (MIT, Apache‑2.0, etc.).

Contact / authors
- Repository maintained by the pro‑nix authors. See git history for contributors.

Commit
------
Replace README with a current overview, quick start and links to docs.
