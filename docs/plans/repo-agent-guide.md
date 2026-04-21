<!-- Русский: комментарии и пояснения оформлены в стиле учебника -->
# Repo agent guide

## Build

Primary build:

```bash
nix flake check
```

Validate all machines explicitly:

```bash
just check-all
```

For the system layer you can still use:

```bash
sudo nixos-rebuild test --flake .#default
```

Portable Emacs profile:

```bash
nix build .#homeConfigurations.<user>.activationPackage
```

Plain `.emacs.d` sync:

```bash
./scripts/emacs-sync.sh ~/.emacs.d
```

## Emacs tests

Run both headless modes:

```bash
./scripts/emacs-verify.sh both
```

Read the latest logs:

```bash
./scripts/emacs-headless-report.sh
```

## Useful tools

- `rg` for search
- `fd` for file discovery
- `git diff --stat` for change scope
- `nixos-rebuild test` for system-level validation
- `nix build` for the portable Home Manager Emacs profile
- `just` as the default workflow wrapper
- `Xvfb` and `script` for Emacs headless verification

## Agent rule

If you change Emacs modules, run the headless test runner and inspect the logs before claiming success.

Do not rely on generated logs as source files; they are evidence, not configuration.

If repeated `nix flake check` runs keep downloading inputs, check that `flake.lock` is committed and that input declarations follow locked refs rather than floating URLs.
