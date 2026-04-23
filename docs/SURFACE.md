Name: Soft Reload (Modules)
Stability: [FLUID]
Spec: Reload individual pro-nix Emacs modules at runtime without restarting Emacs. Modules must be idempotent and expose migrate/reset hooks for complex state. Public API: pro/reload-module, pro/reload-all-modules.
Proof: ERT + manual: (pro/reload-module 'terminals), (pro/reload-all-modules)

Name: Keybindings Surface
Stability: [FLUID]
Spec: Centralized global keybinding surface stored in emacs-keys.org. Modules publish suggested keys via pro/register-module-keys. Suggestions can be auto-merged into emacs-keys.org for review. Loader applies system -> user overrides and handles pending bindings for late-defined commands.
Proof: commands: scripts/generate-key-suggestions.py, scripts/apply-key-suggestions.py, pro-keys-reload (M-x pro/keys-reload)

Name: Package Update (MELPA)
Stability: [FLUID]
Spec: Background batch updater for ELPA/MELPA that refreshes archives and installs/updates packages without blocking interactive Emacs. Public API: pro/update-melpa-in-background (starts background batch process running scripts/melpa-update.el).
Proof: run M-x pro/update-melpa-in-background and inspect buffer *pro-melpa-update*; scripts/melpa-update.el

Name: Nix Site-Lisp Path Surface
Stability: [FLUID]
Spec: Generator (scripts/nix-update-emacs-paths.sh) discovers /nix/store/*/share/emacs/site-lisp and writes emacs/base/nix-emacs-paths.el. Emacs API pro/nix-generate-and-refresh-paths loads paths and refreshes load-path at runtime. Note: native C extensions still require restart.
Proof: ./scripts/nix-update-emacs-paths.sh; M-x pro/nix-generate-and-refresh-paths

Name: Session Save / Soft Restart
Stability: [FLUID]
Spec: Save minimal session state (open files, points, window-state) and restore after restart. API: pro/session-save, pro/session-restore, pro/session-save-and-restart-emacs. Designed to support smooth restart when native libs changed.
Proof: M-x pro/session-save RET; M-x pro/session-restore RET; M-x pro/session-save-and-restart-emacs

Notes:
- All surfaces are conservative: GUI-only features are guarded by display-graphic-p and Nix/native upgrades that touch C-extensions must be followed by a restart (session helper provided).
- For any surface marked [FROID/FLUID] see docs/HOLO.md for Change Gate and proof commands.
