# Opencode

## Current setup

`opencode` is available from the system profile. The repository provides two complementary delivery mechanisms:

- System-wide package: `opencodeCmd`/`opencodeBin` delivered via `environment.systemPackages` (preferred). When present, the binary is placed into `/run/current-system/sw/bin` and is available for all users immediately after `nixos-rebuild switch`.
- Per-user wrapper/bootstrap: `opencodeCmd` (wrapper) still exists and prefers a local binary if present (for example `~/.local/bin/opencode` or `~/.opencode/bin/opencode`). If no binary is found it will attempt to download the official Linux x64 release from the project's GitHub releases and cache it under `~/.local/share/opencode/opencode`.

Default configuration distribution

This repo installs and configures opencode via a dedicated NixOS module `nixos/modules/opencode.nix`. All opencode-related options and behavior are concentrated in that module. The module exposes the following options (documented in Russian in the module source):

- provisioning.opencode.enable (bool) — when `true`, the module will attempt to add a system-wide opencode package from the flake (opencode_from_release) into `environment.systemPackages`.
- provisioning.opencode.userTemplate (string) — path to the default user config template; it will be copied into `/etc/skel/pro-templates/.opencode/config.json` so new users receive a default config.

Note: there is a small compatibility shim `nixos/modules/opencode-system.nix` that preserves older behavior but the authoritative implementation is `nixos/modules/opencode.nix`.

- `opencode.enable` (bool) — when `true`, during system activation the module will copy the template `docs/opencode-default-config.json` into each user's `~/.opencode/config.json` if that file does not already exist. Existing user configs are not overwritten.
- `opencode.userTemplate` (string) — path to a custom template to use instead of the shipped `docs/opencode-default-config.json`.

To enable the behavior add to your host configuration (recommended via `local.nix` or host overlay):

```
provisioning.opencode.enable = true;
provisioning.opencode.userTemplate = /path/to/your/template.json; # optional
```

See `docs/opencode-operation.md` for full operational notes, and `docs/opencode-default-config.json` for the shipped template. The module and its options are documented with Russian comments directly in `nixos/modules/opencode.nix`.

<!-- key shim removed -->

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
