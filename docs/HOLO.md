Stage: RealityCheck
Purpose: Make pro-nix Emacs configuration easily reloadable and self-updating

Intent: Add safe, opt-in mechanisms to update UI, keybindings, modules and packages without requiring a full Emacs restart; provide tooling to refresh Nix-provided site-lisp paths and to perform a controlled restart with session restore when native extensions change.

Pressure: Feature

Surface impact:
- pro-nix Emacs configuration: add "Soft Reload" surface (modules and keys can be reloaded at runtime) [FLUID]
- Keybindings surface: emacs-keys.org enhanced and supports auto-merged module suggestions [FLUID]
- Package update surface: background MELPA updater (batch) [FLUID]
- Nix path surface: site-lisp path generator and in-Emacs refresh (no automatic native rebind) [FLUID]
- Session surface: session save/restore + restart helper for smooth restarts [FLUID]

Proof (how to verify):
- Run headless e2e: ./scripts/emacs-pro-wrapper.sh --batch -l scripts/emacs-e2e-assertions.el -l scripts/emacs-e2e-run-tests.el
- Run key suggestion generator: python3 scripts/generate-key-suggestions.py $(pwd) /tmp/emacs-keys-scan.org
- Apply suggestions: python3 scripts/apply-key-suggestions.py /tmp/emacs-keys-scan.org $(pwd)
- Generate nix paths and refresh in Emacs: ./scripts/nix-update-emacs-paths.sh && M-x pro/nix-generate-and-refresh-paths
- Background package update (batch): M-x pro/update-melpa-in-background and inspect *pro-melpa-update* buffer
- Soft reload modules: M-x pro/reload-module RET terminals RET and M-x pro/reload-all-modules
- Session save/restore: M-x pro/session-save RET and M-x pro/session-restore RET (or M-x pro/session-save-and-restart-emacs)

Change Gate (this HOLO entry):
- Intent: one sentence above
- Pressure: Feature
- Surface impact: listed above
- Proof: commands above
