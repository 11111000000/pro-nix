# Repo agent guide

## Build

Primary build:

```bash
sudo nixos-rebuild test --flake .#pro
```

Or just check evaluation:

```bash
nix flake check
```

## Emacs tests

Run both headless modes:

```bash
./scripts/pro-emacs-headless-test both
```

Read the latest logs:

```bash
./scripts/pro-emacs-headless-report.sh
```

## Useful tools

- `rg` for search
- `fd` for file discovery
- `git diff --stat` for change scope
- `nixos-rebuild test` for system-level validation

## Agent rule

If you change Emacs modules, run the headless test runner and inspect the logs before claiming success.
