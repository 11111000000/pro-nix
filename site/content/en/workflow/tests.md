+++
title = "Tests"
template = "page.html"
weight = 7

[extra]
tldr = "5 layers: flake check (fast), unit (10 scripts), contract (5 scripts), VM (slow, gated), GUI (Xvfb). Run from CI: hds-verify, unit-ci, validate-pr. Locally: just flake-check, just headless-tests, just network-contract, tools/holo-verify.sh."

[[extra.next]]
title = "Per-host checklist"
url = "/workflow/per-host/"

[[extra.next]]
title = "Troubleshooting"
url = "/workflow/troubleshoot/"
+++

# Tests

The test pyramid has five layers. The first two run on every PR;
the rest are gated by `PRO_NIX_RUN_SLOW_CHECKS=1` or by explicit
invocation.

## Layer 1: `nix flake check` (fast, ~30 s)

Runs on every PR via `.github/workflows/flake-check.yml`. It does:

* `nix flake check path:.`
* `./tools/holo-verify.sh` (the orchestrator).

This catches: syntax errors in `.nix` files, `imports` pointing
to missing files, options that do not exist, and most of the
tooling-script bugs.

`nix flake check` is **not** sufficient — it does not catch
`writeShellScript` bugs that only manifest at `nix run` time, and
it does not catch `imports = [ ./broken.nix ]` in a test file that
is not wired into `flake.nix#checks`. See
[Anti-patterns](conventions/anti-patterns.md) for the full list.

## Layer 2: unit tests (10 scripts, <5 s total)

`tools/holo-verify.sh unit` runs `tests/contract/unit/*`:

| File | Asserts |
|------|---------|
| `01-pro-peer-basic.sh` | `pro-peer.nix` declares `enableKeySync`, `keySyncInterval`, `keysGpgPath` |
| `02-emacs-options.sh` | `home-manager.extraSpecialArgs` evaluates |
| `03-llm-tools.sh` | `system-package-sets-dev.nix` references `llm-lab` / `jupyterlab` / `transformers` / `datasets` / `sentencepiece` / `tokenizers` |
| `04-opencode-options.sh` | `programs.opencode-bwrap.enable = true` and `.package` non-empty on `az` user, `huawei` host |
| `05-mkforce-lint-test.sh` | `tools/mkforce-lint.sh` runs (smoke) |
| `06-pro-peer-dryrun.sh` | `scripts/ops-pro-peer-sync-keys.sh --dry-run` does NOT write output file |
| `07-runtime-packages.sh` | `huawei` `systemPackages` contains `gh`, `mc`, `python3`, `htop` |
| `08-pro-privacy-packages.sh` | `huawei` `systemPackages` contains `obfs4`, `meek`, `snowflake` |
| `09-system-packages-eval.sh` | `system-package-sets-dev.nix` evaluates; result contains `direnv`, `bat`, `git`, `cmake` |
| `test_nix_eval_basic.sh` | `flake.nix` exists; trivial `nix eval --expr '{r=1+1;}'` works |

These run via `.github/workflows/unit-ci.yml` on every PR.

## Layer 3: contract tests (5 scripts, <5 s total)

* `tests/contract/pro-network-01.sh` — 5 checks: `pro.hosts` has 4
  entries, `pro-network` configures Avahi + nss-mdns,
  `pro-ssh-clients` generates `ssh_config.d/pro.conf`, headscale
  has `base_domain`/`magic_dns`/`prefix_v4`/`derp`, only `desktop`
  has `headscale.enable = true`.
* `tests/contract/pro-peer-01.sh` — `pro-peer.nix` references
  `/var/lib/pro-peer/authorized_keys`.
* `tests/contract/tor-01.sh` — `pro-privacy.nix` references
  `tor-ensure-perms` or `/var/lib/tor`.
* `tests/contract/surface-headers.sh` — every `modules/*.nix` has
  a `# Название:` header.
* `tests/contract/test_docker_dev.sh` — 6 checks: docker bridge
  172.20.0.0/16, firewall ports 3000/5000/5173/8000/8080/8443 on
  `lo`, system packages include `lazydocker` / `dive` / `ctop` /
  `trivy` / `hadolint` / `sops` / `age`, Emacs `docker` in
  `providedPackages`.
* `tests/contract/test_runtime_packages.sh` — `pi` / `pi-dev`
  wrappers in `systemPackages`, `--help` returns 0.
* `tests/contract/test_live_activation_smoke.sh` — builds
  `huawei` toplevel, runs `nspawn switch-to-configuration`,
  checks for `Rejected send message`.
* `tests/contract/test_system_runtime_paths.spec` — `bash` and
  `ssh` exist at `$out/sw/bin/`.
* `tests/contract/test_surface_health.spec` — `just` is available
  or `scripts/emacs-sync.sh` exists.

Run via `just network-contract` (which runs `pro-network-01.sh`).

## Layer 4: VM tests (slow, ~10 min total)

Gated by `PRO_NIX_RUN_SLOW_CHECKS=1`:

| Test | Asserts |
|------|---------|
| `tests/vm/huawei-boot.nix` | Huawei VM boots clean: no `Got disconnect on API bus`, no `Failed to activate service 'org.freedesktop.systemd1'`, no `Unknown group "netdev"`, no `parse failure`; `dbus-broker` and `NetworkManager` active |
| `tests/vm/test-basic-activation.nix` | `pro-privacy.nix` activation generates valid `tor-ensure-bridges.service` and `tor-ensure-perms.service`; no `Unbalanced quoting`; `ExecStart` contains `/nix/store` path |
| `tests/vm/cf19-switch-dbus-regression.nix` | `busctl Ping`/`ListUnits` baseline OK; after `systemctl daemon-reload`, DBus still resolves systemd manager; no `Rejected send message` |

These use the NixOS test framework. They boot a real NixOS VM and
verify it works. **Slow** because NixOS VM boot + activation takes
1-3 minutes per test.

Run via:

```bash
PRO_NIX_RUN_SLOW_CHECKS=1 nix flake check
```

Or explicitly:

```bash
nix build ".#checks.x86_64-linux.huawei-boot"
nix build ".#checks.x86_64-linux.basic-activation-test"
nix build ".#checks.x86_64-linux.cf19-switch-dbus-regression"
```

## Layer 5: headless + GUI

* `just headless-tests` — full headless ERT suite, both TTY and
  Xvfb (where applicable). Logs to `logs/emacs-headless/<stamp>/`.
* `tests/contract/ert-session.el`, `tests/contract/ert-soft-reload.el`
  — ERT tests for `pro/session-save`, `pro/session-restore`,
  `pro/reload-module`, `pro/reload-all-modules`,
  `pro/session-save-and-restart-emacs`.
* `tests/contract/test-soft-reload.el` — verifies the soft-reload
  module file exists and contains the public API.
* `tests/contract/test-theme-contrast.el` — WCAG-like check:
  `default` face foreground/background contrast ratio ≥ 3.0.
* `tests/contract/test-gui-smoke.el` — checks `tests/gui/gui-smoke.el`
  exists and `HOLO.md` references it.
* `tests/gui/gui-smoke.el` — headless GUI under Xvfb. Verifies
  `(display-graphic-p)`, creates a temporary invisible frame, runs
  `pro-emacs-check-fonts` if available.

## The `holo-verify` orchestrator

`tools/holo-verify.sh` is the single entry point for "all
tests except VM". Modes:

```bash
./tools/holo-verify.sh            # default = unit (10 tests)
./tools/holo-verify.sh unit      # explicit unit
./tools/holo-verify.sh elisp     # helper-check-elisp.sh for repo + user modules
./tools/holo-verify.sh nixos-fast # unit + check-nixos-build + verify-units
./tools/holo-verify.sh full      # all of tests/contract/*
./tools/holo-verify.sh --help
```

Reports whether `HOLO.md` test references match real test files.

## The `surface-lint` and `mkforce-lint` tools

```bash
./tools/surface-lint.sh                    # basic
./tools/surface-lint.sh --check-style     # required header sections + Cyrillic
./tools/surface-lint.sh --enforce-style   # same, exit 1 on violation
./tools/mkforce-lint.sh                    # non-blocking counts
./tools/docs-link-check.sh                 # broken internal links in docs/
```

`surface-lint --check-style` is what enforces the
"Назначение / Цель / Контракт / Побочные эффекты / Proof" header
on every `modules/*.nix`. Add to CI as a required check.

## Scenario tests

`tests/scenario/controlplane_e2e.sh` — starts a mock model-client
(Flask on :31415) + coordinator + worker; POSTs a task to
coordinator :8080; polls `~/.local/state/agents/transcripts/$TASK_ID.json`
for up to 20 s; prints transcript on success. Not in CI — manual
integration test.

`tests/scenario/example_scenario.test` — template for new
scenarios.

## CI workflows (16 total)

| Workflow | What it does |
|----------|--------------|
| `ci.yml` | `nixfmt`, `shellcheck`, Elisp byte-recompile in alpine |
| `change-gate.yml` | Validates PR body has `Intent:` / `Pressure:` / `Surface:` / `Proof:` |
| `elisp-parens.yml` | `scripts/check-elisp-parens.el --dir=emacs` |
| `emacs-ci.yml` | Emacs 30.2 via `ericdallo/setup-emacs`, runs smoke + ERT |
| `emacs-e2e.yml` | Nix-shell with vertico/consult/etc, runs E2E assertions + tests |
| `emacs-headless.yml` | Nix emacs, runs `emacs-headless-test.sh tty` |
| `flake-check.yml` | `nix flake check path:.` + `holo-verify.sh` |
| `gui-smoke.yml` | Xvfb + `tests/gui/gui-smoke.el` |
| `hds-verify.yml` | `holo-verify.sh` + `surface-lint.sh` + `docs-link-check.sh` |
| `holo-verify-fast.yml` | PR-scoped: `surface-lint --check-style` + `holo-verify nixos-fast` |
| `lint-and-tests.yml` | `lint-keys.sh` + `test-emacs-e2e-assertions.el` (apt emacs-nox) |
| `opencode-check.yml` | `surface-lint` (strict) + `holo-verify unit` + `opencode-smoke.sh` + headless ERT |
| `opencode-smoke.yml` | Standalone: `opencode-smoke.sh` |
| `unit-ci.yml` | PR only: `nix flake show --json .` + `holo-verify unit` + `mkforce-lint.sh` + `09-system-packages-eval.sh` |
| `validate-pr.yml` | `nix build '.#nixosConfigurations.cf19.config.system.build.nixos-rebuild'` (60 min timeout) + headless E2E + holo-verify |
| `site-build.yml` | Build + deploy gh-pages (this site) |

## What runs in CI for a typical PR

1. `ci.yml` (nixfmt + shellcheck + Elisp byte-recompile).
2. `change-gate.yml` (PR body format).
3. `flake-check.yml` (full `nix flake check` + holo-verify).
4. `unit-ci.yml` (10 unit tests + `holo-verify unit` + `mkforce-lint` + `09-system-packages-eval.sh`).
5. `lint-and-tests.yml` (lint-keys + E2E assertions).
6. `holo-verify-fast.yml` (`surface-lint --check-style` + `holo-verify nixos-fast`).
7. `surface-lint`, `docs-link-check`, and the rest.

A typical PR runs through all 7 in ~10 minutes.

## What is **not** in CI

* `PRO_NIX_RUN_SLOW_CHECKS=1` (VM tests).
* `tests/scenario/controlplane_e2e.sh`.
* `tests/contract/test_live_activation_smoke.sh` (uses `systemd-nspawn`).
* `vm-switch-loop.sh` (manual regression loop).
* `safe-switch.sh` (the nixos-rebuild dry-activate pre-check).
* `tools/generate-mkforce-json.sh`, `tools/generate-options-md.sh`
  (these regenerate docs; they are not tests).

These are run by hand before major changes.

## Adding a new test

1. Decide the layer: unit (small shell script) or contract
   (medium shell script) or VM (NixOS test).
2. For unit/contract: add to `tests/contract/unit/` or
   `tests/contract/`. Make it `exit 0` on pass, `exit <code>` on
   fail with a clear message.
3. For VM: add to `tests/vm/`. Use `nixosTest`.
4. Wire into `flake.nix#checks` (for VM) or `tools/holo-verify.sh`
   (for unit/contract).
5. Add to a CI workflow (or to a new one if the test is slow).
6. Document the test in [Reference → Tests](reference/tests.md)
   (regenerated by `just site-regen`).
