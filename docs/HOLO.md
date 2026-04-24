Stage: RealityCheck

Purpose: Keep the repository's public system contract explicit while restoring a usable NixOS profile. The current change is intentionally narrow: recover core runtime tools, document the regression, and keep proof attached to the observable path contract.

Invariants:
- INV-Core-IO-Boundary: system policy stays in NixOS modules and host overlays.
- INV-Determinism: the same config inputs produce the same system profile.
- INV-Canonical-Roundtrip: frozen payloads and contracts keep reproducible proofs.
- INV-Compat-Policy: runtime contracts evolve additively unless a migration is documented.
- INV-Traceability: every public change carries Intent, Pressure, Surface impact, and Proof.
- INV-Surface-First: public meaning changes start in SURFACE.md.
- INV-Single-Intent: one change, one dominant goal.

Decisions:
- [Draft] Keep `environment.systemPackages` consolidated in `configuration.nix` while explicitly pinning core runtime tools there. Exit: `bash` and `ssh` are present in `/run/current-system/sw/bin` on the default host builds, and the contract test passes.
