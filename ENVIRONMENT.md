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
just build
just test
just flake-check
just headless
just headless-report
```

## Agent contract

When you edit Emacs or Nix, prefer this order:

1. inspect the relevant file
2. patch the smallest possible area
3. run `just flake-check`
4. run the headless Emacs test
5. read the latest logs

If the change touches Emacs UI, test both `tty` and `xorg`.

Avoid committing generated logs or `result/`; they are runtime artifacts.
