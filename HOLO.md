# HOLO — Holographic Manifest

Stage: RealityCheck

Purpose: Provide a concise manifest of the repository's public contract, baseline invariants, and key decisions so agents and maintainers can reason about safe changes.

Invariants:
1) INV-Core-IO-Boundary: Core logic is IO-agnostic; side effects live in adapters (modules/pro-*-nix, emacs adapters).
2) INV-Determinism: Deterministic outputs for equal inputs in core functions and tests.
3) INV-Canonical-Roundtrip: Frozen payloads that are serialized must roundtrip (encode∘decode = id) where applicable.
4) INV-Surface-First: Public meaning changes start in SURFACE.md and are accompanied by Proof before code-only changes.
5) INV-Traceability: Every change follows the Change Gate (Intent/Pressure/Surface impact/Proof) and references relevant tests.

Decisions:
- [Draft] Emacs profile: provide a default portable Emacs + EXWM profile. Exit: provide a migration plan and Proof (headless tests) before freezing.
- [FROZEN] Soft Reload: provide safe, opt-in mechanisms to update UI, keybindings, modules and packages without requiring a full Emacs restart; provide tooling to refresh Nix-provided site-lisp paths and to perform a controlled restart with session restore when native extensions change. Exit: Soft Reload surfaces implemented and verified via headless ERT tests. Proof: `./scripts/emacs-pro-wrapper.sh --batch -l scripts/emacs-e2e-assertions.el -l scripts/emacs-e2e-run-tests.el` + manual test commands listed in SURFACE.md.

- [Draft] Pro-peer: Discovery & Key Sync
  Pressure: Ops
  Rationale: pro-peer is an operational surface that manages distribution of authorized_keys and encrypted per-host artifacts. It affects host setup and security; changes touching it require operator coordination and proof (smoke scripts + systemd unit checks).
  Exit: Documented migration and a minimal smoke-test (scripts/pro-peer-sync-keys.sh) present.

Proofs / Verification Commands (add to Change Gate):
- Contract tests: `tests/contract/test_surface_health.spec`
- Vertical scenario: `tests/scenario/example_scenario.test`
- Soft Reload e2e: `./scripts/emacs-pro-wrapper.sh --batch -l scripts/emacs-e2e-assertions.el -l scripts/emacs-e2e-run-tests.el`
- Pro-peer smoke: `bash scripts/pro-peer-sync-keys.sh --help` (or run systemd unit in dry-run)
- Samba automount smoke: `bash scripts/mount-smb.sh --help`

Notes:
- Add or freeze decisions only when Exit criteria and Proof are present. Use the Change Gate format in PR descriptions.
