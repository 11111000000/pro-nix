# Opencode

## Current setup

`opencode` is available from the system profile. The repo uses a PATH wrapper around the upstream `@opencode/cli` package so the command is available immediately.

## Credentials

- Do not store API keys in Nix files.
- Use `auth-source` or shell environment variables.
- If you need `AITUNNEL_KEY`, export it at runtime.

## Check

- `which opencode`
- `opencode --version`
