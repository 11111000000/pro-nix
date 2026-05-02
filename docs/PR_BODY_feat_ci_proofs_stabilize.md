Intent
Make CI and repository-local proofs honest and verify pro-privacy systemd units by removing fragile inline ExecStart quoting.

Pressure
Ops / Bug

Surface impact
Touches Soft Reload proof (tests/contract/test-soft-reload.el) [FROZEN] and CI workflows; no runtime semantic changes expected except safer unit scripts.

Proof
./tools/holo-verify.sh unit
nix build .#nixosConfigurations.huawei.config.system.build.toplevel --out-link result
systemd-analyze verify result/etc/systemd/system/tor-ensure-bridges.service result/etc/systemd/system/tor-ensure-perms.service

Migration
none

Changes
- tests/contract/test-soft-reload.el: robustly find pro-reload.el
- tools/mkforce-lint.sh: scope search to focused areas
- .github/workflows/*: enforce flake-check and HDS checks (remove masking), sync nix channel to 25.11
- configuration.nix: avoid self-reference of environment.systemPackages; disable optional heavy packages by default; add gh to dev/packages
- modules/pro-privacy.nix: install helper scripts via writeShellScriptBin and reference them in systemd units (avoid inline ExecStart quoting)

Notes
- Branch: feat/ci-proofs-stabilize (pushed)
- Commits: see git log; key commits include changes to CI, mkforce-lint, soft-reload test, configuration.nix, and pro-privacy.

How to open PR locally
1. Ensure gh is authenticated: `gh auth login` or `gh auth status` inside `nix develop .#devShells.x86_64-linux.default`
2. Run: `gh pr create --title "chore(ci): enforce HDS/flake checks, tighten mkforce-lint, fix soft-reload proof, harden pro-privacy units" --body-file docs/PR_BODY_feat_ci_proofs_stabilize.md --base main`
