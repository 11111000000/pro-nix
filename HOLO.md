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

Notes:
- Add or freeze decisions only when Exit criteria and Proof are present. Use the Change Gate format in PR descriptions.
