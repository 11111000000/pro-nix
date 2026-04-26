This overlay (emacs-extra.nix) conditionally defines additional emacs
packages when the Nixpkgs used provides `emacsPackageFromRepository`.

Usage notes:
- The overlay is safe to import in newer Nixpkgs. In older Nixpkgs the
  attribute may be missing; the overlay will then be a no-op.
- `flake.nix` exposes a `pkgsOverlay` variable so callers can reference
  overlay-provided packages explicitly when needed (for example in
  a devShell or for testing).

If you intend to add more packages here, ensure that the target Nixpkgs
version supports `emacsPackageFromRepository` or provide an alternate
recipe (fetchFromGitHub + buildEmacsPackage) to maintain compatibility.
