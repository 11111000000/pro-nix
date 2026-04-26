**Testing Guide**

Short summary
-
This document explains how to run flake/Nix checks, contract and scenario tests, and Emacs E2E in this repository. Follow the HDS cycle: Surface → Proof → Code → Verify.

Flake / Nix
-
- Quick check: `nix flake check`
- Build host toplevel: `nix build .#nixosConfigurations.<host>.config.system.build.toplevel`
- Build all hosts: `nix run .#check-all` or `nix build .#checks.x86_64-linux.default`
- Devshell: `nix develop .#devShells.x86_64-linux.default` creates an emacs wrapper at `./.pro-emacs-wrapper/emacs-pro` and adds it to PATH.

Repository-local verification
-
- HDS verify: `./tools/holo-verify.sh`
- Surface lint: `./tools/surface-lint.sh`
- Docs link check: `./tools/docs-link-check.sh`

Contract and scenario tests
-
- Contract proofs: `bash tests/contract/*.sh` (e.g. `tests/contract/test_surface_health.spec`)
- Scenario tests: `bash tests/scenario/*.test` (e.g. `tests/scenario/example_scenario.test`)

Emacs E2E
-
- Headless E2E: `./scripts/dev-emacs-pro-wrapper.sh --batch -l scripts/test-emacs-e2e-assertions.el -l scripts/test-emacs-e2e-run-tests.el`
- Alternative ERT run: `emacs --batch -l emacs/base/init.el -f ert-run-tests-batch`

Recommended verify command before PR
-
```
nix flake check --show-trace && ./tools/holo-verify.sh && bash tests/contract/test_surface_health.spec
```

CI hints
-
- GitHub Actions workflows run `nix flake check` and Emacs E2E via `./scripts/dev-emacs-pro-wrapper.sh`.
- If CI shows "Git tree is dirty" — commit or stash local changes before rerunning.

HDS checklist
-
- Update SURFACE.md before code when public contract changes.
- Add/adjust Proof tests for any [FROZEN] items.
- Include Change Gate block in PR.
