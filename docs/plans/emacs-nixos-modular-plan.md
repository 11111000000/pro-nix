# Plan: Modular Emacs in NixOS with user-selectable modules

## Goal
Build a minimal EXWM-capable Emacs setup that is updated by `nixos-rebuild`, while still letting the user choose which Emacs modules to load without rebuilding NixOS for every Lisp change.

## Requirements
1. `nixos-rebuild switch --flake .#nixos` must update the system Emacs baseline.
2. EXWM must start from one authoritative session entry.
3. The user must be able to choose enabled modules themselves.
4. Lisp/module changes should not require `nixos-rebuild`.
5. The setup should stay minimal, modular, and understandable.

## Proposed architecture

### 1. System layer
NixOS owns the stable binary/runtime layer:
- `emacs` or `emacs-gtk`
- EXWM dependencies and X11 helpers
- `git`, `nix`, `nodejs`, `typescript-language-server`, `prettier`
- `gptel`-related runtime tools if needed
- `magit` support tools
- `nix-mode` support tools
- JS language tooling
- EXWM session launcher and `.desktop` entry

This layer is rebuilt by `nixos-rebuild`.

### 2. User layer
The user owns a writable Emacs tree, for example `~/.config/emacs`:
- `early-init.el`
- `init.el`
- `site-init.el` generated or managed by NixOS
- `modules.el` with the selected module list
- `modules/*.el` for actual features

This layer changes without NixOS rebuild.

### 3. Loader contract
The system `init.el` should only do three things:
1. Load `site-init.el`
2. Load `modules.el`
3. Load each module from `modules/` in order

That keeps the system baseline declarative and the user selection flexible.

## Module model

### Recommended modules
- `core` - startup defaults, paths, safety, basic UI
- `ui` - theme, modeline, completion, fonts
- `git` - `magit`, `transient`, `with-editor`
- `nix` - `nix-mode`, formatting, nix-related helpers
- `js` - `eglot`, JS/TS modes, JSON support
- `ai` - `gptel` and local/remote AI integration
- `exwm` - window manager session logic and EXWM glue

### User choice
The user edits only `modules.el`, for example:

```elisp
(setq my-emacs-modules '(core ui git nix js ai exwm))
```

This makes feature selection explicit and reversible.

## Update strategy

### What rebuilds
- Emacs binary version
- session launcher
- desktop integration
- system packages and toolchain
- `site-init.el`

### What does not rebuild
- `modules.el`
- files under `~/.config/emacs/modules/`
- user-specific keybinds and personal tweaks

### Package availability rule
Any module enabled by the user must have its dependencies available in the system layer already.
Otherwise Emacs will load the manifest but fail on missing packages.

## Implementation steps

### Phase 1: Decide the split
1. Keep EXWM launch in one system-owned entry.
2. Move the Emacs baseline into a generated `site-init.el`.
3. Keep user module selection outside the Nix store.

### Phase 2: Create loader files
1. Add a minimal system-generated `site-init.el`.
2. Add a small `init.el` that loads `site-init.el` and `modules.el`.
3. Add `modules.el` as the user manifest.
4. Add `modules/` with one file per feature.

### Phase 3: Provide system dependencies
1. Add the minimal Emacs package set to `system-packages.nix`.
2. Ensure EXWM, Git, Nix, JS, and AI dependencies are present.
3. Keep the launcher thin and deterministic.

### Phase 4: Preserve user control
1. Make module selection happen only in `modules.el`.
2. Ensure the loader tolerates missing optional modules gracefully.
3. Document which modules require which system packages.

### Phase 5: Verify behavior
1. Rebuild NixOS.
2. Start EXWM.
3. Modify `modules.el` without rebuilding.
4. Confirm module changes appear after Emacs restart.

## Risks
- If dependencies are not preinstalled system-wide, user-selected modules may fail to load.
- If there are multiple EXWM entry points, environment drift will appear.
- If the Emacs tree is placed fully in the Nix store, user changes will again require rebuild.
- If the module system becomes too clever, it will become harder to maintain than the original setup.

## Success criteria
- System updates land through `nixos-rebuild`.
- User module selection is editable without rebuild.
- EXWM starts from one stable path.
- AI, Git, Nix, and JS workflows work out of the box.
- The configuration remains small enough to understand at a glance.
