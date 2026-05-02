# HOLO — Holographic Manifest

Stage: RealityCheck


Purpose: Provide concise manifest of the repository's public contract, базовые инварианты и ключевые решения, чтобы агенты и мейнтейнеры могли разумно и безопасно вносить изменения.

Invariants:
1) INV-Core-IO-Boundary: Ядро логики не должно содержать побочных эффектов; побочные эффекты реализуются в адаптерах (Nix-модули, emacs adapters).
2) INV-Determinism: Функции и сборки, при прочих равных входных данных, дают детерминированный результат.
3) INV-Canonical-Roundtrip: Файлы/передаваемые данные, помеченные как frozen, обязаны проходить roundtrip (encode∘decode = id) там, где это применимо.
4) INV-Surface-First: Любые изменения публичного смысла начинаются с обновления SURFACE.md и сопровождаются Proof до изменения кода.
5) INV-Traceability: Каждое изменение проходит Change Gate (Intent/Pressure/Surface impact/Proof) и ссылается на соответствующие тесты.
6) INV-Docs-Russian: Вся документация, комментарии и docstring в репозитории — на русском языке. Это не косметическое требование, а контракт читаемости для команды.
7) INV-Test-Coverage-for-Surface: Каждая запись в SURFACE должна иметь Proof — однозначную команду/скрипт/тест, проверяющий поведение.
8) INV-Deterministic-Flake-Outputs: Flake outputs, используемые как Proof или CI-артефакты, должны быть buildable локально и воспроизводимы в CI. Любое изменение, затрагивающее flake outputs, сопровождается Proof и проверкой в CI.
9) INV-OneFile-OneResponsibility: Один файл — одна ответственность. Если файл растёт за пределы одной ответственности, изменение оформляется через Change Gate и предлагается декомпозиция.
10) INV-No-Secrets: Репозиторий не содержит секретов; любые упоминания секретов сопровождаются явной инструкцией о хранении вне репозитория.


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
  Rationale: pro-peer is an operational surface that управляет распространением authorized_keys и пер-узловыми артефактами. Изменения требуют координации операторов и Proof (smoke scripts + systemd unit checks).
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
