<!-- Русский: комментарии и пояснения оформлены в стиле учебника -->
# Plan: Harmonic `pro` architecture

## Purpose
Turn the current configuration into a portable `pro` system that is easy to install, easy to understand, easy to override, and hard to accidentally break.

## Critique of the current plan

### 1. Too much structure before the center is stable
The previous plan had many parts at once:
- host profiles
- equal users
- portable bootstrap
- Emacs base
- Emacs overrides
- disable markers

This is reasonable, but only if there is one clear center. Without that center, the plan becomes a map of intentions rather than a usable system.

### 2. The base was too strong in some places and too weak in others
The base must work by default, but also be replaceable.

If the base is too strong:
- user overrides become awkward
- Emacs Lisp drifts back into Nix logic
- the system feels imposed

If the base is too weak:
- the default system does not boot into a useful desktop
- EXWM becomes optional in theory only

### 3. Machine choice and user behavior were not clearly separated
Machine-specific choice should happen only where it is actually needed.
User behavior should remain shared across all machines.

### 4. The Emacs loader needed one clear rule
The loader must not be clever.

It should do one thing only:
1. look for a user module
2. if not found, load the system base module
3. if disabled, skip the base

### 5. The plan still carried a bit of single-user thinking
The system must not revolve around one user's home directory.
It should revolve around the `pro` profile and shared policy.

## What harmony means here

Harmony is not compromise-by-vagueness.
Harmony is a clean division of responsibilities.

### Invariant
Things that should stay the same everywhere:
- user equality
- loader precedence
- Emacs Lisp file format
- canonical Emacs init directory is `~/.config/emacs`
- shared system policy

### Variable
Things that may change by machine:
- hardware profile
- kernel/device quirks
- storage layout
- boot details

### Personal
Things that belong to the user:
- `~/.config/emacs/modules/*.el`
- personal keybinds
- personal package choices
- optional user-specific overrides

## Harmonious architecture

### 1. System core
The repo provides one shared NixOS core for all hosts.

This core owns:
- package policy
- desktop/session wiring
- common services
- Emacs base deployment

### 2. Machine overlays
Each machine-specific layer adds only hardware-specific data.

### 3. Equal users
The system defines four equal accounts:
- `az`
- `zo`
- `la`
- `bo`

### 4. Emacs base and override
Emacs is split into:
- portable base modules in `emacs/base/modules/`
- user modules in `~/.config/emacs/modules/`

User files win over system files when the names match.
The canonical session entry uses `--init-directory ~/.config/emacs`.

### 5. Bootstrap
A bootstrap script downloads or activates the repo and applies the chosen machine-specific overrides.

## File layout

```text
pro/
  flake.nix
  hosts/
    thinkpad/
    desktop/
    cf19/
  modules/
    pro-services.nix
    pro-storage.nix
    pro-privacy.nix
    pro-users.nix
    pro-users-nixos.nix
    pro-users-wsl.nix
    pro-users-termux.nix
  emacs/
    base/
      early-init.el
      init.el
      site-init.el
      modules/
        core.el
        ui.el
        git.el
        nix.el
        js.el
        ai.el
        exwm.el
    home-manager.nix
  docs/
    plans/
    analyse/
```

## Emacs contract

### Load order
For module `M`:
1. `~/.emacs.d/modules/M.el`
2. portable base `emacs/base/modules/M.el`

If the user file exists, it wins.
If not, the system base file loads.

### Disable rule
If `~/.emacs.d/.disable-nixos-base` exists, the system base is skipped entirely.

### Lisp rule
Emacs behavior lives in normal `.el` files only.
Nix may install or copy these files, but not author their behavior inline.

## Installation flow

1. User downloads the repo.
2. User runs the bootstrap script.
3. The script asks for the device profile.
4. The script selects or writes the host profile.
5. The script runs `nixos-rebuild` for that profile.

## Why this is harmonious

### Benefits
- one center, many surfaces
- system defaults without user captivity
- portable install path
- clear machine separation where needed
- plain-file Emacs modules
- user override without rebuild

### Tradeoffs
- the system must ship a safe superset of runtime dependencies
- the loader must remain intentionally simple
- the repo structure must stay disciplined

## Refactor phases

### Phase 1: Create the core
Move shared policy into common modules.

### Phase 2: Add machine overlays
Create empty stubs only if a machine actually needs them.

### Phase 3: Normalize users
Define equal user templates for all four accounts.

### Phase 4: Ship the Emacs base
Install the default Emacs base and its module set.

### Phase 5: Add override loading
Implement user-first module lookup.

### Phase 6: Add bootstrap selection
Make install-time host selection explicit.

### Phase 7: Document the contract
Document precedence, paths, and host rules in `docs/plans` and `docs/analyse`.

## Success criteria

- Fresh install works from a downloaded repo.
- The installer can apply machine-specific overrides only when needed.
- `az`, `zo`, `la`, and `bo` remain equal.
- Emacs Lisp stays in `.el` files.
- EXWM is available by default but not imposed.
- User module overrides are natural and simple.
- The whole system remains understandable at a glance.
