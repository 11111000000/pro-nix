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
  
  Migration:
    Impact: Soft Reload touches Emacs session state and may require restart when native C-extensions or compiled elisp change; scope: Emacs GUI UX Layer, modelines, icon fonts, completion backends (posframe), and site-lisp paths.
    Strategy: additive_v2 — provide an explicit runtime "pro-emacs-reload" command that attempts a best-effort reload of site-lisp and module state; when native extensions are detected changed (native-compile or binary modules), surface a controlled restart prompt that preserves session state to disk and restores where possible.
    Window/Version: v1 (initial rollout) — opt-in behind `pro.emacs.softReload.enable = true` and feature gate; full default rollout deferred until Proof passes.
    Data/Backfill: store session serialization in `~/.local/state/pro-emacs/session-<timestamp>.el` (or `~/.emacs.d/.local/session/`) and provide tooling to inspect and selectively restore buffers, frames and window-configs.
    Rollback: disable `pro.emacs.softReload.enable` and restart Emacs; session files preserved for manual restore.
    Tests:
      - Keep: existing headless ERT tests and UI smoke tests.
      - Add: `tests/contract/test-soft-reload.el` (soft reload helper presence), `tests/contract/test-theme-contrast.el` (face contrast checks).
- [Draft] Pro-peer: Discovery & Key Sync
  Pressure: Ops
  Rationale: pro-peer is an operational surface that manages distribution of authorized_keys and encrypted per-host artifacts. It affects host setup and security; changes touching it require operator coordination and proof (smoke scripts + systemd unit checks).
  Exit: Documented migration and a minimal smoke-test (scripts/pro-peer-sync-keys.sh) present.

- [Draft] LLM Research Surface: provide a reproducible notebook-based environment for model inspection, prompt tests, dataset exploration, and lightweight evaluation. Exit: `llm-lab` is exposed on PATH and covered by `tests/contract/unit/03-llm-tools.sh`.

Proofs / Verification Commands (add to Change Gate):
- Contract tests: `tests/contract/test_surface_health.spec`
- Vertical scenario: `tests/scenario/example_scenario.test`
- Soft Reload e2e: `./scripts/emacs-pro-wrapper.sh --batch -l scripts/emacs-e2e-assertions.el -l scripts/emacs-e2e-run-tests.el`
- Pro-peer smoke: `bash scripts/pro-peer-sync-keys.sh --help` (or run systemd unit in dry-run)
- Samba automount smoke: `bash scripts/mount-smb.sh --help`

- HDS seed (local): `docs/hds-llm-seed-en.md` — repository-local copy of the HDS LLM seed used by agents and verification steps.
- Repository-local verify tools:
  - `./tools/holo-verify.sh`
  - `./tools/surface-lint.sh`
  - `./tools/docs-link-check.sh`
- Testing guide: `docs/TESTING.md`
- PR template (Change Gate): `.github/PULL_REQUEST_TEMPLATE.md`

- LLM research entrypoint: `llm-lab`

Notes:
- Add or freeze decisions only when Exit criteria and Proof are present. Use the Change Gate format in PR descriptions.
