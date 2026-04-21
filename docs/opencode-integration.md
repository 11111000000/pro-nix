# Opencode

## Current setup

`opencode` is available from the system profile. The wrapper in this repository now prefers a local binary if present (for example `~/.local/bin/opencode` or `~/.opencode/bin/opencode`). If no binary is found it will attempt to download the official Linux x64 release from the project's GitHub releases and cache it under `~/.local/share/opencode/opencode`.

Default configuration distribution

This repo can optionally install a default `opencode` user config when the system is activated. The NixOS module `nixos/modules/opencode-config.nix` provides options:

- `opencode.enable` (bool) — when `true`, during system activation the module will copy the template `docs/opencode-default-config.json` into each user's `~/.opencode/config.json` if that file does not already exist. Existing user configs are not overwritten.
- `opencode.userTemplate` (string) — path to a custom template to use instead of the shipped `docs/opencode-default-config.json`.

To enable the behavior add to your host configuration:

```
opencode.enable = true;
opencode.userTemplate = /path/to/your/template.json; # optional
```

See `docs/opencode-operation.md` for full operational notes, and `docs/opencode-default-config.json` for the shipped template.

Notes:
- This is a best-effort bootstrap: if your environment restricts network access or the release asset is missing, install the official binary manually or place it in `~/.local/bin`.
- Do not store API keys in Nix files. Use `auth-source` or shell environment variables.

## Credentials

- Do not store API keys in Nix files.
- Use `auth-source` or shell environment variables.
- If you need `AITUNNEL_KEY`, export it at runtime.

## Check

- `which opencode`
- `opencode --version`
