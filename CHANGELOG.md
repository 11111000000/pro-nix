# Changelog

All notable changes to this repository are recorded in this file.

## 2026-04-21 — pro-packages integration, pro-compat, Nix support

- Add `pro-packages` runtime engine for safe package installation:
  - Interactive prompt-and-install policy for missing packages (i/a/s/c).
  - Decisions persisted in `~/.config/emacs/decisions.el`.
  - Noninteractive behaviour: installations skipped by default; override with PRO_PACKAGES_AUTO_INSTALL=1 for automated builds.
- Add `pro-compat` minimal shim layer (UI zoom commands and safe fallbacks for missing packages).
- Integrate Nix ⇄ Emacs: `emacs/home-manager.nix` gains `pro.emacs.providedPackages` option that generates `~/.config/emacs/provided-packages.el` at activation; Emacs reads this file early to avoid prompts for Nix-provided packages.
- Update modules to consult `pro--package-provided-p` / `pro-packages--maybe-install` before attempting to require optional packages.
- Fix `modules/pro-peer.nix` by merging conditional `config` fragments to avoid duplicate attribute errors.
- Add ERT test for pro-packages load, headless test script usage improved, docs added.

Notes:
- The `PRO_PACKAGES_AUTO_INSTALL` environment variable allows CI/image builds to perform noninteractive installs when desired.
- Keep the list of `providedPackages` minimal in Nix to preserve reproducibility and security.
