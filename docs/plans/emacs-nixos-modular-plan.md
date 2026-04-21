<!-- Русский: комментарии и пояснения оформлены в стиле учебника -->
# Plan: Base Emacs for pro-nix

## Goal
Build a minimal Emacs base for `pro-nix` that is updated by `nixos-rebuild` on NixOS, while Lisp edits remain writable and do not require a rebuild.

## Dialectical frame
- Thesis: NixOS must provide a ready-made Emacs/EXWM baseline.
- Antithesis: the user must be able to change Lisp and module selection without rebuilding the system.
- Synthesis: Nix owns the stable shell and runtime, while Emacs modules live in a writable user tree with a single loader contract.

## Contract
1. One authoritative session entry launches EXWM.
2. The system layer provides only the binary/runtime baseline and the launcher.
3. The user layer owns `~/.config/emacs`.
4. `modules.el` is the only place where module selection is edited.
5. `modules/*.el` may override system defaults by name.
6. Optional modules must fail gracefully when absent.

## Target layout
- `~/.config/emacs/early-init.el`
- `~/.config/emacs/init.el`
- `~/.config/emacs/site-init.el`
- `~/.config/emacs/modules.el`
- `~/.config/emacs/modules/*.el`

## Loader order
1. `site-init.el` prepares the base environment.
2. `modules.el` defines the selected module list.
3. Each module is loaded from the user tree first, then from the system fallback layer.

## Recommended modules
- `core` — startup defaults, paths, safety, basic UI
- `ui` — theme, modeline, completion, fonts
- `git` — `magit`, `transient`, `with-editor`
- `nix` — `nix-mode`, formatting, nix helpers
- `js` — `eglot`, JS/TS modes, JSON support
- `ai` — `gptel` and provider policy
- `exwm` — session logic and EXWM glue

## What rebuilds
- Emacs binary version
- session launcher
- desktop integration
- system packages and toolchain
- `site-init.el`

## What does not rebuild
- `modules.el`
- files under `~/.config/emacs/modules/`
- user keybinds and personal tweaks

## System responsibilities
- Ship Emacs and EXWM dependencies.
- Provide X11/session helpers and a thin launcher.
- Provide the external tools needed by enabled modules.
- Keep the launcher deterministic and small.

## User responsibilities
- Edit `modules.el` to choose features.
- Add or replace modules in `~/.config/emacs/modules/`.
- Keep personal keybinds and tweaks outside the system layer.

## Risks
- Missing system dependencies can make an enabled module fail at load time.
- Multiple EXWM entry points will cause environment drift.
- Putting the Lisp tree into the Nix store will restore rebuild coupling.

## Success criteria
- `nixos-rebuild` updates the base Emacs layer.
- `modules.el` changes take effect after Emacs restart without rebuild.
- EXWM starts from one stable path.
- The configuration stays small, understandable, and override-friendly.
