# pro-packages Implementation Plan

This document describes the concrete implementation steps for the
`pro-packages` prompt-and-install mechanism and the small compatibility
layer `pro-compat`.

Goals:
- Ensure Nix-provided packages are recognized early.
- Prompt users when a package is missing and allow installation from MELPA.
- Keep use-package as a configuration DSL; avoid macro timing issues.
- Keep shims minimal and transparent.

Files added by implementation:
- `emacs/base/modules/pro-packages.el` (prompt/install engine)
- `emacs/base/modules/pro-compat.el` (minimal shims)
- `docs/emacs-package-management/PRO-PACKAGES-SPEC.md` (spec)

Changes applied:
- site-init now loads `~/.config/emacs/provided-packages.el` early.
- packages.el bootstraps use-package if missing.
- Selected modules updated to check `pro--package-provided-p` before requiring optional packages.

Next steps to finalize:
1. Add Nix/home-manager snippet to generate `~/.config/emacs/provided-packages.el`.
2. Update modules that currently rely on implicit installs (wrap with `pro-packages--maybe-install`).
3. Add ERT tests to validate fboundp for keys and headless runs.
4. Document workflow in README and SURFACE.md.
