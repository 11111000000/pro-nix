# Opencode

## Current setup

`opencode` is available from the system profile. The wrapper in this repository now prefers a local binary if present (for example `~/.local/bin/opencode` or `~/.opencode/bin/opencode`). If no binary is found it will attempt to download the official Linux x64 release from the project's GitHub releases and cache it under `~/.local/share/opencode/opencode`.

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
