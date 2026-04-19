# Repository workflow

## Recommended tools

- `just`
- `nix`
- `git`
- `rg`
- `fd`
- `nixos-rebuild`
- `Xvfb`
- `script`

## Common commands

```bash
./bootstrap/install.sh
just build
just test
just flake-check
just check-all
just headless
just headless-report
./scripts/emacs-sync.sh ~/.emacs.d
./scripts/emacs-verify.sh both
./scripts/emacs-headless-report.sh
```

## Command layout

- `install:*` - installation entrypoints
- `check:*` - validation entrypoints
- `headless:*` - Emacs verification entrypoints
- `emacs:*` - portable Emacs helpers

Prefer `just` targets for routine work. Use `just flake-check` or `just check-huawei` instead of raw `nix` commands unless a lower-level command is explicitly required.

`scripts/emacs-sync.sh` always preserves an existing target tree by moving it aside to `*.backup.<timestamp>` before writing a fresh copy.

## Installation matrix

- New NixOS machine: `sudo nixos-generate-config` then `sudo nixos-rebuild switch --flake .#default`
- Predefined NixOS host: `sudo nixos-rebuild switch --flake .#thinkpad|desktop|cf19`
- Portable Emacs with Home Manager: import `emacs/home-manager.nix`
- Plain Emacs tree: `./scripts/emacs-sync.sh ~/.emacs.d`
- WSL/Termux without Nix: use `./scripts/emacs-sync.sh ~/.emacs.d` and запускайте Emacs напрямую

## Agent contract

When you edit Emacs or Nix, prefer this order:

1. inspect the relevant file
2. patch the smallest possible area
3. run `just flake-check`
4. if the change touches Emacs, run the headless Emacs test
5. read the latest logs

For routine work, use `just` targets first; avoid typing raw `nix`/`nixos-rebuild` commands unless the task explicitly requires them.

If the change touches Emacs UI, test both `tty` and `xorg`.

If you need to validate every machine profile, run `just check-all` explicitly. Default checks should stay scoped to `huawei` and should be used only before commit or on explicit request.

If Nix keeps re-fetching inputs, make sure `flake.lock` is present and that `flake.nix` does not point to drifting branch URLs without a lockfile.

Home Manager is configured to avoid user-profile package installation clashes with `nix profile install`.

Avoid committing generated logs or `result/`; they are runtime artifacts.

The headless runner uses a disposable HOME under `logs/emacs-headless/<timestamp>/home` so it does not depend on the user's live Emacs state.
