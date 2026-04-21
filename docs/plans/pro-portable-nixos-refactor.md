<!-- Русский: комментарии и пояснения оформлены в стиле учебника -->
# Plan: Portable `pro` NixOS refactor

## Goal
Turn the current machine-specific NixOS setup into a portable `pro` configuration that:
- installs from a downloaded repository plus a bootstrap script
- supports machine-specific overrides when needed
- treats `az`, `zo`, `la`, and `bo` as equal users
- keeps system settings shared and editable only through config files
- keeps Emacs Lisp in normal `.el` files, never inline in Nix
- provides a base Emacs layer that works by default and can be overridden naturally

## Dialectical critique of the current state

### Thesis
The current repo already contains a lot of working system logic: hardware, users, desktop, Emacs, services, and session glue.

### Antithesis
The same repo is too coupled to one machine and one person:
- hard-coded paths like `/home/zoya`
- one large `configuration.nix`
- user and system concerns mixed together
- Emacs Lisp embedded too close to Nix logic
- host-specific assumptions leaking into shared config

### Synthesis
The configuration should become a portable platform:
- shared common modules for all machines
- machine-specific overlays only for hardware-specific differences
- user accounts described symmetrically
- Emacs as a base layer plus overrideable modules
- a bootstrap path that selects the right host profile at install time

## Design principles

1. One shared system core.
2. Multiple host profiles.
3. Equal users with equal rights.
4. Emacs Lisp only in plain `.el` files.
5. User overrides should win naturally over the base.
6. Rebuilds should target one chosen host profile, not a moving mixture.

## Target repository structure

```text
pro/
  flake.nix
  flake.lock
  bootstrap/
    install-pro.sh
    choose-host.sh
  modules/
    common/
    users/
    emacs/
    desktop/
    services/
  hosts/
    laptop/
    cf19/
    desktop/
    custom/
  docs/
    plans/
    analyse/
  emacs/
    base/
    modules/
```

## Target runtime model

### System layer
The system layer provides:
- NixOS system definition
- packages
- services
- desktop/session integration
- Emacs base and session launcher

### User layer
The user layer provides:
- personal modules
- personal Emacs overrides
- optional per-user tweaks

### Machine layer
Each machine-specific layer provides only:
- hardware-specific kernel and device settings
- machine-specific drivers
- boot and storage details
- any board-specific quirks

## User model

The four users must be equal in policy and structure:
- `az`
- `zo`
- `la`
- `bo`

They should share:
- the same group set
- the same sudo policy, if sudo is enabled
- the same access to desktop/session features
- the same baseline shell and session environment

The only differences should be personal data and home content, not system privileges.

## Emacs model

### Base Emacs
The NixOS base should provide:
- a working default Emacs
- EXWM as one available window manager/session mode
- a minimal set of common packages for AI, Git, Nix, and JS
- a deterministic launcher

### Override model
User Emacs modules should be loaded with this precedence:
1. `~/.emacs.d/modules/<name>.el`
2. system base module for `<name>`

That means a user can replace the base `exwm` module by creating a file with the same name.

### Disable model
The base must be possible to disable completely with a marker file.

### Lisp placement
All Lisp should live in normal `.el` files:
- no inline Lisp in Nix strings for actual behavior
- Nix may copy or install `.el` files, but not author them inline

## Machine overlays

Create empty stubs only when a machine actually needs them.

Only the machine-specific layer should change when the machine changes.
Common user and system behavior should remain shared.

## Installation flow

1. User downloads the repo.
2. User runs a bootstrap script.
3. Script asks which hardware profile to install.
4. Script writes or selects the needed machine overrides.
5. Script runs `nixos-rebuild` for that setup.
6. Future rebuilds continue using the same shared core.

This makes installation feel like a guided setup while keeping the result declarative.

## Configuration flow

### What changes often
- user Emacs modules
- user-facing config files
- host profile specifics when hardware changes

### What changes rarely
- shared package set
- session launcher logic
- common user policy
- base Emacs module names and precedence rules

### What should never drift
- user equality
- one machine-specific override set per chosen machine, if needed
- Emacs Lisp location and override rules

## Refactor phases

### Phase 1: Split common and machine logic
Extract shared settings from the monolithic config into common modules and machine stubs.

### Phase 2: Normalize users
Define `az`, `zo`, `la`, and `bo` as equivalent accounts using one shared user template.

### Phase 3: Separate Emacs base from Lisp
Move Emacs behavior into ordinary `.el` files and keep Nix responsible only for installation and launching.

### Phase 4: Add bootstrap selection
Create a script that selects machine-specific overrides and runs the matching rebuild.

### Phase 5: Add override precedence
Implement user-first module lookup for Emacs modules.

### Phase 6: Document the contract
Document file locations, precedence rules, and profile selection in `docs/analyse` and `docs/plans`.

## Risks

- Too many host profiles can fragment the config if common logic is not extracted well.
- If the Emacs loader becomes clever, it will become brittle.
- If user and system modules are not clearly separated, override behavior will become confusing.
- If equal-user policy is not encoded centrally, the four accounts will drift over time.
- If hardware profiles are not explicit, rebuilds may accidentally target the wrong machine.

## Success criteria

- The repo can be installed from a fresh download.
- The installer can apply machine-specific overrides when needed.
- Rebuilds stay on one shared core.
- `az`, `zo`, `la`, and `bo` behave the same from the system perspective.
- Emacs Lisp lives in normal `.el` files only.
- The base Emacs works by default and is easy to override or disable.
- The config remains understandable and portable.
