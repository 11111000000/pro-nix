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
just check-fast
just flake-check
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

Prefer the smallest command that proves the change. Use raw `nix eval`/`nix build` for targeted checks when a `just` target would evaluate a broader system profile.

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
3. run the minimal Proof from `AGENTS.md`
4. escalate only if the local Proof does not cover the risk
5. read logs only for commands that failed

For routine agent work, avoid full host builds and `nix flake check` unless the task changes flake outputs, host finalization or activation behavior.

If the change touches Emacs UI, test `tty` first. Add `xorg` only for display-manager, EXWM, font, icon or clipboard behavior.

If you need to validate every machine profile, run `just check-all` explicitly. Matrix checks are release/review checks, not the default development loop.

If Nix keeps re-fetching inputs, make sure `flake.lock` is present and that `flake.nix` does not point to drifting branch URLs without a lockfile.

Home Manager is configured to avoid user-profile package installation clashes with `nix profile install`.

Avoid committing generated logs or `result/`; they are runtime artifacts.

The headless runner uses a disposable HOME under `logs/emacs-headless/<timestamp>/home` so it does not depend on the user's live Emacs state.
