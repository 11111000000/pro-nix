# Plan: `pro-nix` code quality refactor

## Goal
Reduce coupling in the current NixOS and Emacs setup by making each layer own one job only:
- system policy in NixOS modules
- package groups in dedicated package modules
- Emacs runtime and Lisp loading in the Emacs layer
- host-specific hardware values in host files

## Current friction
- `configuration.nix` is still a coordinator for too many concerns.
- `system-packages.nix` mixes CLI tools, desktop apps, Emacs packages, and helper wrappers.
- Emacs is launched from more than one place, and not all of them use the same `emacsPkg`.
- `system-packages.nix` is imported as a package list, but its Emacs section really belongs to the Emacs contract.
- Some files contain formatting drift and hand-edited shell snippets that are hard to keep aligned.

## Refactor principles
1. One file, one responsibility.
2. One Emacs binary contract everywhere.
3. System packages and Emacs packages stay separate.
4. Host-specific values stay in host modules.
5. Shared session logic should be defined once and reused.

## Target layout
- `configuration.nix` becomes a thin system composition root.
- `system-packages.nix` becomes a pure list of non-Emacs system packages.
- `emacs/` owns the Emacs binary, startup scripts, and Lisp loading rules.
- `hosts/huawei/configuration.nix` owns machine-specific storage and boot details.
- Other hosts follow the same pattern when they need special values.

## Refactor phases

### Phase 1: Normalize package ownership
- Keep `just`, `jq`, and other CLI tools in `environment.systemPackages`.
- Move Emacs Lisp packages out of the general system package list.
- Pass `emacsPkg` explicitly everywhere Emacs packages are derived.

### Phase 2: Unify Emacs runtime
- Make the launcher scripts use the same Emacs derivation as the package set.
- Ensure `home-manager.nix`, `site-init.el`, and session scripts agree on loader paths.
- Keep `modules.el` and user override precedence as the only source of module selection.

### Phase 3: Split the package layer
- Separate CLI tools from GUI apps and editor tooling.
- Keep wrapper scripts close to the packages they wrap.
- Remove implicit coupling between desktop utilities and editor tooling.

### Phase 4: Move machine data out of the global profile
- Keep disk UUIDs, boot details, and device-specific swaps in host modules.
- Leave the shared profile free of machine-only values.

### Phase 5: Clean formatting and naming drift
- Fix broken indentation and nested blocks.
- Use one naming style for helper bindings.
- Remove dead or duplicated comments when they stop explaining the layer.

## Verification
- Build `huawei` after each structural change.
- Confirm `just` and `jq` remain available in the system profile.
- Confirm Emacs starts from one runtime contract only.
- Confirm `system-packages.nix` stays syntax-clean and does not define Emacs ownership twice.

## Risks
- Moving Emacs packages too early can break the launcher contract.
- Splitting package files too aggressively can make the repo harder to navigate.
- Host-specific values copied into the wrong layer can reintroduce coupling.

## Success criteria
- The system profile is smaller and easier to reason about.
- Emacs uses one binary/package source of truth.
- Package ownership is obvious from file names.
- Host-specific values no longer leak into shared config.
- The repo is easier to extend without editing `configuration.nix` for every change.
