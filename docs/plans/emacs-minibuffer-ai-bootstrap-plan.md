<!-- План по устранению проблем запуска Emacs: автозагрузка локальных helper-пакетов, корректная инициализация AI (gptel), и удобный minibuffer/M-x -->
# Plan: Emacs minibuffer & AI bootstrap remediation

Intent: Fix Emacs startup failures observed in logs: failed auto-install of local helper packages (pro-fix-corfu), "Wrong type argument: commandp, gptel" when pro-ai activates, and poor M-x/minibuffer UX. Make startup robust across Nix-provided and ELPA-managed package sources.

Pressure: Bug / Ops

Surface impact: (none) — internal runtime behaviour of Emacs loader and UX; no external public API changes.

Proof: Verification steps (manual / automated):
- Start Emacs GUI/TTY and inspect *Messages* for errors about missing packages or wrong-type arguments.
- Verify M-x opens consult-M-x (or fallback) and minibuffer navigation (C-n/C-p, TAB) cycles candidates.
- Run headless smoke tests: `./scripts/dev-emacs-pro-wrapper.sh --batch -l scripts/test-emacs-e2e-assertions.el -l scripts/test-emacs-e2e-run-tests.el` (repo-provided e2e smoke)

Planned Changes (minimal, incremental):
1. Early-load repository modules dir into `load-path` from `early-init.el` so local helper modules (pro-fix-corfu) are discoverable by `locate-library` and `require`. (Implemented)
2. Ensure module directory is present on `load-path` from `init.el` as well so interactive runs see helpers early. (Implemented)
3. Avoid eager backend registration in `ai.el`; defer registration until `gptel` is actually loaded or when user opens the AI entry. Make `pro-ai-open-entry` robust to `gptel` being a function vs an interactive command. (Implemented)
4. Improve minibuffer UX: enable vertico when available, set up candidate navigation keys, and prefer `consult-M-x` for M-x if consult is present; ensure bindings are installed lazily and non-fatally. (Implemented)
5. Add a docs/plans entry describing the change and verification commands. (This file)

Implementation notes & rationale:
- The root cause for `pro-fix-corfu` auto-install attempts is that the bootstrap installer treats package names uniformly; adding the repository modules directory to `load-path` early makes `locate-library` succeed and prevents trying to fetch a local helper from MELPA.
- Calling `gptel` as an interactive command when it isn't one produces `Wrong type argument: commandp`. The remedy is to test `commandp` and fall back to direct function calls when appropriate.
- The minibuffer UX improvements favour modern stack (vertico + consult + orderless) while keeping corfu for in-buffer completion; configuration loads packages lazily via `pro-ui--try-require` and `pro-packages--maybe-install` so startup remains robust in different environments (Nix-provided vs ELPA).

What I have changed so far (files modified):
- emacs/base/early-init.el — added early load-path insertion for repository modules
- emacs/base/init.el — ensure modules dir on load-path during init
- emacs/base/modules/ai.el — defer eager backend registration; defensive gptel invocation
- emacs/base/modules/nav.el — prefer consult-M-x when available

Next steps you can run locally to verify:
1. Start Emacs normally (GUI or TTY) and inspect *Messages* for errors.
2. Run the repo smoke tests: `./scripts/emacs-pro-wrapper.sh --batch -l scripts/emacs-e2e-assertions.el -l scripts/emacs-e2e-run-tests.el`.
3. In Emacs: M-x pro-ai-open-entry (should not error if gptel missing; should notify). M-x and minibuffer navigation should use consult/vertico where available.

If further failures appear (e.g. other local helper packages still attempted to be auto-installed), we'll extend the early load-path logic and add explicit `provide` markers to the repo helpers so `locate-library`/`require` unambiguously succeed.

Signed-off-by: OpenCode (automated remediation)
