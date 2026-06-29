+++
title = "Scripts"
sort_by = "weight"
template = "page.html"

[extra]
tldr = "All 0 shell scripts under scripts/ and bin/. The first non-comment line of each is shown as the one-line purpose."
+++

# Scripts

<span class="gen-badge">auto-gen</span> Generated 2026-06-16 from `scripts/*` and `bin/*`.

> pro-nix ships a thick layer of operational shell. The page below is a flat catalogue —
> to understand *what* a script does and *when* to use it, read the
> [Workflow → troubleshooting](workflow/troubleshoot.md) and the
> individual workflow pages.

**Total:** 0 scripts (0 in `scripts/`, 0 in `bin/`).

## bin/ (deployed to $HOME/bin by helper-switch.sh)

| Path | Size | Shebang | First-line purpose |
|------|------|---------|---------------------|
| `bin/torwrap` | 2571 B / 71 LOC | `/usr/bin/env bash` | set -euo pipefail |

## scripts/ (operational helpers)

| Path | Size | Shebang | First-line purpose |
|------|------|---------|---------------------|
| `scripts/agent-conventions-check.sh` | 3104 B / 89 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/check_privacy_proxies.sh` | 8180 B / 161 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/collect-switch-logs.sh` | 5270 B / 101 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/deploy-agent-configs.sh` | 2879 B / 73 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/dev-analyse.sh` | 6871 B / 145 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/dev-apply-key-suggestions.py` | 2264 B / 67 LOC | `/usr/bin/env python3` | """Apply suggested keys from suggestions file into emacs-keys.org. |
| `scripts/dev-build-system.sh` | 416 B / 14 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/dev-deploy-emacs-from-repo.sh` | 1431 B / 45 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/dev-emacs-pro-wrapper.sh` | 1054 B / 29 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/dev-emacs-sync.sh` | 1484 B / 38 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/dev-emacs-with-packages.nix` | 255 B / 6 LOC | `` | let |
| `scripts/dev-generate-key-suggestions.el` | 1819 B / 35 LOC | `` | ;; Usage: emacs -Q --batch -l scripts/generate-key-suggestions.el --eval "(generate-keys \"/path/to/repo\" \"/tmp/out.or |
| `scripts/dev-generate-key-suggestions.py` | 2492 B / 74 LOC | `/usr/bin/env python3` | """Generate key suggestions by parsing pro/register-module-keys forms. |
| `scripts/dev-generate-provided-packages.el` | 2966 B / 55 LOC | `` | ;; Usage: emacs --batch -l scripts/generate-provided-packages.el --eval '(generate-provided-packages "nix/provided-packa |
| `scripts/dev-generate-provided-packages.sh` | 700 B / 28 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/dev-merge-suggestions-into-keys.sh` | 3009 B / 80 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/dev-nix-build-and-share.sh` | 839 B / 30 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/dev-nix-update-emacs-paths.sh` | 931 B / 36 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/dev-patch-pro-provides.sh` | 2269 B / 55 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/dev-regenerate-provided-packages` | 554 B / 15 LOC | `/bin/sh` | set -eu |
| `scripts/dev-regenerate-provided-packages.el` | 1438 B / 29 LOC | `` | ;; Usage: emacs --batch -Q -l scripts/regenerate-provided-packages.el |
| `scripts/dev-rename-modules-pro.sh` | 3263 B / 93 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/dev-suggest-surface-updates.sh` | 3374 B / 66 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/emacs-headless-test.sh` | 593 B / 18 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/helper-apply-sysctl.sh` | 800 B / 25 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/helper-audio-diag.sh` | 5349 B / 96 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/helper-bash1.sh` | 1714 B / 62 LOC | `` | need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing: $1" >&2; exit 1; }; } |
| `scripts/helper-benchmark-workload.sh` | 1760 B / 59 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/helper-check-elisp-parens.el` | 4967 B / 127 LOC | ` /usr/bin/env emacs --script` | ;; Script: check-elisp-parens.el |
| `scripts/helper-check-elisp.sh` | 2512 B / 76 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/helper-check-nixos-build.sh` | 916 B / 44 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/helper-collect-org-babel-python-info.sh` | 3801 B / 97 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/helper-collect-system-info.sh` | 2063 B / 80 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/helper-enable-zram-safe.sh` | 1192 B / 39 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/helper-install-nerd-fonts.sh` | 951 B / 24 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/helper-install-ollama-model.sh` | 431 B / 17 LOC | `/usr/bin/env bash` | set -e |
| `scripts/helper-interactive-measure.sh` | 530 B / 19 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/helper-lint-keys.sh` | 398 B / 12 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/helper-melpa-update.el` | 856 B / 18 LOC | `` | (require 'package) |
| `scripts/helper-nix-mirror-test.sh` | 3686 B / 92 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/helper-parse-emacs-logs.sh` | 687 B / 30 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/helper-safe-mktemp` | 2824 B / 109 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/helper-sound.sh` | 5676 B / 99 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/helper-switch.sh` | 7363 B / 167 LOC | `/usr/bin/env bash` | HOST_ARG="${1:-}" |
| `scripts/helper-test-keys.el` | 701 B / 21 LOC | `/usr/bin/env emacs --script` | ;;; Тест загрузки клавиш из org-таблицы |
| `scripts/helper-tray-test.sh` | 4668 B / 151 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/install-pi-packages.sh` | 2752 B / 95 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/opencode-smoke.sh` | 883 B / 25 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/ops-backup-hiddenservice.sh` | 832 B / 33 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/ops-ensure-tor.sh` | 4612 B / 135 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/ops-mount-smb.sh` | 3874 B / 120 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/ops-proctl` | 381 B / 24 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/ops-pro-peer-acceptor.sh` | 899 B / 28 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/ops-pro-peer-canary.sh` | 1398 B / 49 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/ops-pro-peer-master.sh` | 5321 B / 159 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/ops-pro-peer-sync-keys.sh` | 1816 B / 71 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/ops-pro-peer-wg-quick-wrapper.sh` | 596 B / 17 LOC | `/bin/sh` | WGCONF="$1" |
| `scripts/ops-pro-samba-setup-users.sh` | 5055 B / 164 LOC | `/run/current-system/sw/bin/bash` | set -euo pipefail |
| `scripts/ops-pro-samba-sync-keys.sh` | 982 B / 43 LOC | `/run/current-system/sw/bin/bash` | set -euo pipefail |
| `scripts/ops-pro-samba-toggle.sh` | 1017 B / 44 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/ops-push-nix-to-peers.sh` | 937 B / 41 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/ops-run-samba-diagnostics.sh` | 2074 B / 82 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/ops-wifi-recover.sh` | 3405 B / 105 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/pro-load-agent-env.sh` | 4446 B / 113 LOC | `/usr/bin/env bash` | [ -n "${PRO_AGENT_ENV_LOADED:-}" ] && return 0 2>/dev/null || true |
| `scripts/pro-peer-backup-hiddenservice.sh` | 537 B / 16 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/pro-peer-ensure-tor-perms.sh` | 503 B / 20 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/pro-peer-sync-wrapper.sh` | 386 B / 10 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/pro-peer-yggdrasil-wrapper.sh` | 202 B / 6 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/pro-samba-sync-keys-wrapper.sh` | 266 B / 7 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/pro-tor` | 12560 B / 394 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/README.md` | 1712 B / 41 LOC | `` | Files: |
| `scripts/run-basic-test.sh` | 1906 B / 42 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/run_via_torsocks.sh` | 947 B / 34 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/safe-switch.sh` | 2275 B / 43 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/site-extract-ai-models.py` | 6622 B / 121 LOC | `/usr/bin/env python3` | """Render emacs/base/modules/ai-models.json as a Zola reference page (both langs).""" |
| `scripts/site-extract-ci.py` | 5636 B / 129 LOC | `/usr/bin/env python3` | """List .github/workflows/*.yml into a Zola reference page (both languages).""" |
| `scripts/site-extract-defcustom.py` | 6502 B / 164 LOC | `/usr/bin/env python3` | """Extract defcustom / defgroup / defvar from emacs/base/modules/pro-*.el |
| `scripts/site-extract-keys.py` | 8067 B / 147 LOC | `/usr/bin/env python3` | """Extract emacs-keys.org table and write a Zola-compatible Markdown file |
| `scripts/site-extract-scripts.sh` | 8089 B / 183 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/site-extract-submodules.py` | 6472 B / 131 LOC | `/usr/bin/env python3` | """Extract .gitmodules + each submodule's README first lines. |
| `scripts/site-extract-tests.py` | 6098 B / 138 LOC | `/usr/bin/env python3` | """List the test suite (tests/) into a Zola reference page (both languages).""" |
| `scripts/site-regen.sh` | 2492 B / 60 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/submodules-ssh.sh` | 1976 B / 68 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/switch.sh` | 156 B / 4 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/sync-submodules.sh` | 3780 B / 69 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/test-emacs-e2e-assertions.el` | 1407 B / 41 LOC | `` | ;; Run under: emacs --batch -l scripts/emacs-e2e-assertions.el |
| `scripts/test-emacs-e2e-run-tests.el` | 317 B / 7 LOC | `` | (setq ert-runner-options '( :reporter ert-progress)) |
| `scripts/test-emacs-e2e-test.el` | 1843 B / 35 LOC | `` | ;; Usage: emacs --batch -Q -l emacs-e2e-test.el |
| `scripts/test-emacs-headless-report.sh` | 734 B / 25 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/test-emacs-headless.sh` | 4077 B / 126 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/test-emacs-headless-test.sh` | 5073 B / 141 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/test-emacs-verify.sh` | 158 B / 5 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/test-in-container.sh` | 3720 B / 73 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/test-minimal-e2e.sh` | 3127 B / 63 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/test-pro-emacs-headless-test` | 71 B / 2 LOC | `/usr/bin/env bash` | exec "$(dirname "$0")/emacs-headless-test.sh" "$@" |
| `scripts/test-run-emacs-e2e.sh` | 1412 B / 40 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/test-smoke-load-modules.sh` | 1035 B / 38 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/update-pi-version.sh` | 2729 B / 93 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/verify-units.sh` | 3043 B / 71 LOC | `/usr/bin/env bash` | set -euo pipefail |
| `scripts/vm-switch-loop.sh` | 1613 B / 55 LOC | `/usr/bin/env bash` | set -euo pipefail |

## How to use

- **Direct invocation:** `./scripts/helper-switch.sh huawei`
- **Through `just`:** `just <recipe>` (see [Workflow → just recipes](workflow/just.md))
- **Bootstrap integration:** `just switch` runs `helper-switch.sh` which
  deploys everything in `bin/` to `$HOME/bin` and adds that directory to
  `PATH` in `~/.profile`.

## Categories (by name prefix)

| Prefix | Group | Examples |
|--------|-------|----------|
| `helper-*` | Diagnostic and one-shot helpers | `helper-audio-diag.sh`, `helper-sysctl.sh` |
| `dev-*` | Developer workflow | `dev-emacs-sync.sh`, `dev-analyse.sh`, `dev-rename-modules-pro.sh` |
| `ops-*` | Operations (production-y) | `ops-ensure-tor.sh`, `ops-mount-smb.sh`, `ops-pro-samba-setup-users.sh` |
| `test-*` | Test runners | `test-emacs-headless.sh`, `test-minimal-e2e.sh` |
| `run-*` | Direct invocations | `run-basic-test.sh`, `run_via_torsocks.sh` |
| `pro-*` | Top-level user-facing CLIs | `pro-tor`, `pro-load-agent-env.sh` (sourced) |
| `update-*` | Updaters | `update-pi-version.sh` |
| `safe-*` | Safer wrappers | `safe-switch.sh`, `safe-mktemp` |
| `verify-*` | CI / smoke verifications | `verify-units.sh` |
| `collect-*` | Log / info collectors | `collect-switch-logs.sh` |
| `sync-*` | State synchronizers | `sync-submodules.sh` |
| `install-*` | One-shot installers | `install-pi-packages.sh` |
| `deploy-*` | Config deployers | `deploy-agent-configs.sh` |
| `emacs-*` | Emacs test harnesses | `emacs-headless-test.sh`, `emacs-verify.sh` |
| `vm-*` | VM-specific runners | `vm-switch-loop.sh` |
| `agent-*` | Agent conventions | `agent-conventions-check.sh` |
