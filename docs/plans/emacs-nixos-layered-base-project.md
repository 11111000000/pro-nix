# Project: Layered Emacs base in NixOS

## Purpose
Create an Emacs base that is:
- present by default after `nixos-rebuild`
- minimal and usable out of the box
- easy to extend with user modules
- easy to replace module-by-module
- easy to disable entirely

The base should add EXWM as one possible window manager/session mode and provide a minimal working EXWM config, but never block the user from swapping in their own framework or disabling the base.

## Core idea
Use a two-layer load order:
1. User layer first, if it exists: `~/.config/emacs/modules/<name>.el`
2. NixOS base layer second: `~/.config/nixos/...` generated module files

That gives the user the natural ability to override the base by simply creating a file with the same module name in their own Emacs tree.

## Dialectical structure

### Thesis
The system should provide a ready-made Emacs foundation that works immediately after rebuild.

### Antithesis
The user must not be trapped inside that foundation. They should be able to replace any base module, including EXWM, with their own version.

### Synthesis
The base becomes a fallback layer, not a cage. It is loaded only when the user has not provided an overriding module.

## Resulting load contract

For module `M`, the loader checks in this order:
1. `~/.config/emacs/modules/M.el`
2. `~/.config/nixos/emacs/modules/M.el` or generated equivalent in the Nix store

If a user file exists, it wins.
If not, the NixOS base file loads.

This gives natural override semantics without requiring any special user syntax.

## Disable semantics

The base can be disabled completely by a marker file, for example:
- `~/.config/emacs/.disable-nixos-base`

If the marker exists:
- NixOS base modules are skipped
- only user modules load
- EXWM is not forced by the system

## What the base provides

### Always available
- Emacs binary and session launcher
- EXWM session glue
- X11 helpers and env setup
- basic Git/Nix/JS/AI runtime dependencies

### Minimal EXWM base
- desktop/session entry
- `exwm` module
- tray and session services
- sane defaults for `xset`, `xhost`, `Xresources`, and env vars

### Optional features
- `git`
- `nix`
- `js`
- `ai`
- UI polish modules

## What the user can do

### 1. Extend the base
Create additional modules in `~/.config/emacs/modules/` and add them to the user manifest.

### 2. Replace a base module
Create `~/.config/emacs/modules/exwm.el` and it will shadow the system `exwm` module.

### 3. Disable the base
Create `.disable-nixos-base` and use only personal modules or a different framework.

## NixOS integration points

The base should be built into `~/.config/nixos` in a way that is easy to maintain:
- `configuration.nix` owns system packages and session entry generation
- `system-packages.nix` owns binary runtime dependencies
- `systemd-user-services.nix` owns tray/session helpers
- `conf/*.in` owns shell/session templates
- `docs/plans` and `docs/analyse` document the contract

## Generated links and discoverability

Yes, generated hyperlinks are useful here.

Recommended generated artifacts:
- `.desktop` files for EXWM and related sessions
- desktop launchers for browser and editor entry points
- symlinks or generated loader references for module files
- one canonical launcher that can be invoked from GDM, Xsession, or desktop menus

The goal is not web hyperlinks, but navigable desktop/session links that make the base feel native.

## Why this is the right balance

### Benefits
- system-level reproducibility
- user-level freedom
- one default path that always works
- no rebuild needed for ordinary Lisp edits
- no need to re-architect the whole desktop to swap one module

### Tradeoffs
- the system must ship a safe superset of package dependencies
- the loader must be simple enough to avoid confusing override rules
- the base and user modules must have clear names and clear precedence

## Implementation outline

### Phase 1: Base loader
Create a loader that resolves module names with user-first precedence, then system fallback.

### Phase 2: EXWM base module
Add a minimal EXWM base module that works immediately after rebuild.

### Phase 3: Override path
Allow `~/.config/emacs/modules/exwm.el` to replace the base EXWM module transparently.

### Phase 4: Disable switch
Add `.disable-nixos-base` handling.

### Phase 5: Documentation
Document the exact resolution order and the supported module names in `docs/analyse` and `docs/plans`.

## Success criteria
- Emacs starts with the NixOS base by default.
- The user can override any module by creating a same-named file.
- The user can disable the whole base.
- EXWM is available as a default option, not a lock-in.
- The structure is easy to reason about from the repo layout alone.
