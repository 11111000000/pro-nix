<!-- Русский: комментарии и пояснения оформлены в стиле учебника -->
# Plan: Emacs 30+ package management for `pro-nix`

## Goal

Make Emacs packages available in a way that satisfies both reproducibility and freshness:
- packages from GNU ELPA, NonGNU ELPA, and MELPA should install normally;
- git-backed packages should be installable and upgradeable from inside Emacs;
- if a Nix-provided version is stale, the Emacs user layer can supersede it;
- the design targets Emacs 30 or newer only.

## Contract

1. Nix provides the Emacs runtime and system dependencies.
2. Emacs manages Lisp packages in the user layer.
3. `package.el` is enabled explicitly, not implicitly at startup.
4. `package-vc` is the native path for git-based package installs.
5. MELPA is accepted as a source for fast-moving packages.
6. Built-in package upgrades are allowed only selectively.

## Proposed architecture

### Layer 1: Nix foundation
- Emacs 30+
- git
- curl / gnutls / make / pkg-config
- UI and session dependencies

### Layer 2: Emacs package manager
- `package-enable-at-startup` set to `nil` in early init
- `package-archives` set to GNU ELPA, NonGNU ELPA, and MELPA
- `package-initialize` or explicit activation controlled by the loader

### Layer 3: User package sources
- archive packages via `package-install`
- git packages via `package-vc-install`
- upgrades via `package-upgrade`, `package-upgrade-all`, and `package-vc-upgrade`

## Recommended file changes

1. `emacs/base/early-init.el`
   - disable automatic package activation

2. `emacs/base/init.el` or `site-init.el`
   - require and initialize `package`
   - set package archives and archive priorities
   - load `package-vc`

3. `emacs/base/modules/core.el` or a dedicated package module
   - expose helper commands for package installation and upgrades
   - optionally provide a bootstrap command for first-time installs

4. `docs/`
   - document archive policy, VC policy, and upgrade rules

5. `system-packages.nix`
   - remove Emacs Lisp packages that should live in the user layer only
   - keep only runtime/system dependencies and the Emacs binary itself

6. `emacs-keys.org`
   - bind package helpers to a dedicated prefix that does not collide with project navigation

## Migration steps

1. Remove obvious user-layer Lisp packages from Nix, starting with `gptel`.
2. Keep the corresponding package in the Emacs package layer and install it from ELPA or VC.
3. Add package helpers and archive policy in the Emacs loader.
4. Use `package-vc` for git-only dependencies and `package-install` for archive packages.
5. Review the remaining Nix package list and classify each entry as runtime, tool, or Emacs Lisp.
6. Document the final split so future changes do not reintroduce split-brain ownership.

## Emacs commands to support

- `M-x list-packages`
- `M-x package-install`
- `M-x package-upgrade`
- `M-x package-upgrade-all`
- `M-x package-vc-install`
- `M-x package-vc-upgrade`
- `M-x package-vc-checkout`

## Policy decisions

### Archive priority
Prefer explicit priorities if MELPA and ELPA versions can diverge.

### Built-in upgrades
Allow `package-install-upgrade-built-in`, but do not default bulk operations to it unless you really want archive versions to replace built-ins.

### Reproducibility
Use Nix to pin the Emacs runtime, not every Lisp package.
If a package must be reproducible, pin it by archive version or VC revision at the Emacs layer.

## Risks

- Two package managers at once can create split-brain if the same package is installed both in Nix and in user ELPA.
- MELPA freshness is useful, but it weakens exact reproducibility unless versions are tracked.
- `package-vc` is native and simple, but revision tracking needs discipline if you want repeatability.

## Success criteria

- Fresh packages can be installed without rebuilding NixOS.
- VCS packages can be installed and upgraded from Emacs.
- The base Emacs still starts cleanly under NixOS.
- Package policy is documented as a stable contract.
