# Emacs headless changelog

## What changed

- Added a disposable-home headless test runner: `scripts/test-emacs-headless.sh`.
- Added a log parser: `scripts/parse-emacs-logs.sh`.
- Added ERT coverage for base Emacs startup and module loading in `emacs/base/modules/tests.el`.
- Added shared headless helpers in `emacs/base/modules/test-helpers.el`.
- Wired the test runner into `just` with `headless-tests` and `headless-parse` targets.
- Extended `.gitignore` for Emacs-generated temporaries like `*.elc`, `*.eln`, autosave, and backup clutter.

## Verification

- `./scripts/test-emacs-headless.sh tty`
- `./scripts/test-emacs-headless.sh both`

## Notes

- The tests run against a disposable `HOME` and do not depend on the user's live `~/.emacs.d`.
- Logs are written under `logs/emacs-tests/<timestamp>/` and can be summarized with the parser.
