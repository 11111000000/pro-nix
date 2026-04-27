# HOLO — Holographic Manifest

Stage: RealityCheck

Purpose: Provide a concise manifest of the repository's public contract, baseline invariants, and key decisions so agents and maintainers can reason about safe changes.

Invariants:
1) INV-Core-IO-Boundary: Core logic is IO-agnostic; side effects live in adapters (modules/pro-*-nix, emacs adapters).
2) INV-Determinism: Deterministic outputs for equal inputs in core functions and tests.
3) INV-Canonical-Roundtrip: Frozen payloads that are serialized must roundtrip (encode∘decode = id) where applicable.
4) INV-Surface-First: Public meaning changes start in SURFACE.md and are accompanied by Proof before code-only changes.
5) INV-Traceability: Every change follows the Change Gate (Intent/Pressure/Surface impact/Proof) and references relevant tests.
6) INV-Package-Sync: nix/provided-packages.nix ↔ emacs/base/provided-packages.el синхронизированы; скрипт regeneration согласует списки.
7) INV-Module-Trace: site-init.el логирует загрузку модулей в *Messages*; pro-epistemology.el отслеживает источники знания.
8) INV-Unit-Safety: systemd unit files must pass `systemd-analyze verify` and contain no `Unbalanced quoting` or `parse failure`; use explicit paths in ExecStart, avoid embedding `pkgs.writeShellScriptBin` inside Nix strings.

Decisions:
- [FROZEN] Emacs Base: provide a default portable Emacs + EXWM profile via home-manager.nix. Verified via tests/contract/unit/02-emacs-options.sh.
- [FROZEN] Soft Reload: provide safe, opt-in mechanisms to update UI, keybindings, modules and packages without requiring a full Emacs restart; provide tooling to refresh Nix-provided site-lisp paths and to perform a controlled restart with session restore when native extensions change. Exit: Verified via ERT tests (tests/contract/ert-soft-reload.el). Proof: `./scripts/emacs-pro-wrapper.sh --batch -l tests/contract/ert-soft-reload.el`

  Migration:
    Impact: Soft Reload touches Emacs session state and may require restart when native C-extensions or compiled elisp change; scope: Emacs GUI UX Layer, modelines, icon fonts, completion backends (posframe), and site-lisp paths.
    Strategy: additive_v2 — provide an explicit runtime "pro-emacs-reload" command that attempts a best-effort reload of site-lisp and module state; when native extensions are detected changed (native-compile or binary modules), surface a controlled restart prompt that preserves session state to disk and restores where possible.
    Window/Version: v1 (initial rollout) — opt-in behind `pro.emacs.softReload.enable = true` and feature gate; full default rollout deferred until Proof passes.
    Data/Backfill: store session serialization in `~/.local/state/pro-emacs/session-<timestamp>.el` (or `~/.emacs.d/.local/session/`) and provide tooling to inspect and selectively restore buffers, frames and window-configs.
    Rollback: disable `pro.emacs.softReload.enable` and restart Emacs; session files preserved for manual restore.
    Tests:
      - Keep: existing headless ERT tests and UI smoke tests.
      - Add: `tests/contract/ert-soft-reload.el` (ERT tests for soft reload), `tests/contract/ert-session.el` (ERT tests for session).

- [FROZEN] Peer Discovery: provide Avahi + SSH hardening + Yggdrasil + WireGuard Helper. Verified via tests/contract/unit/01-pro-peer-basic.sh.
  Pressure: Ops
  Rationale: pro-peer is an operational surface that manages distribution of authorized_keys and encrypted per-host artifacts. It affects host setup and security; changes touching it require operator coordination and proof (smoke scripts + systemd unit checks).
  Exit: Smoke test present and passing.

- [Draft] LLM Research Surface: provide a reproducible notebook-based environment for model inspection, prompt tests, dataset exploration, and lightweight evaluation. Exit: `llm-lab` is exposed on PATH and covered by `tests/contract/unit/03-llm-tools.sh`.

- [Draft] Package Knowledge Graph: provide pro-epistemology.el for epistemic tracing of package sources. Exit: pro-epistemology.el created and covered by tests.

- [FROZEN] Tor Ensure Services: provide tor-ensure-bridges and tor-ensure-perms with correct ExecStart paths; use after=dbus-broker.service polkit.service to avoid race condition. Exit: systemd-analyze verify passes; no "Unbalanced quoting" or "parse failure" in journalctl.
  Pressure: Ops
  Rationale: Incorrect ExecStart quoting (derivation-to-string conversion) caused systemd to ignore units, leading to cascade failures and reboots on live switch.
  Exit: ExecStart uses explicit store paths via "${pkgs.writeShellScriptBin "name" ''...''}/bin/name";, not inline Nix strings with embedded writeShellScriptBin.
  Proof: `tests/contract/validate-units.sh` (build etc, verify units, check for quoting/parse errors).

Proofs / Verification Commands (add to Change Gate):
- Contract tests: `tests/contract/test_surface_health.spec`
- Vertical scenario: `tests/scenario/example_scenario.test`
- Soft Reload e2e: `./scripts/emacs-pro-wrapper.sh --batch -l scripts/emacs-e2e-assertions.el -l scripts/emacs-e2e-run-tests.el`
- Pro-peer smoke: `bash scripts/ops-pro-peer-sync-keys.sh --help` (or run systemd unit in dry-run)
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
