+++
title = "The stack"
sort_by = "weight"
template = "section.html"

[extra]
tldr = "NixOS 25.11 (pin), Emacs 30, pi + opencode + EMCP, EXWM + Sway + i3, Tor + headscale. All versions are pinned, all choices are visible."
+++

The stack is what you would get if you took "I want a portable workstation" as
a strict requirement and started drawing the dependency graph.

## Layer 1: NixOS 25.11

The system is NixOS, pinned to `nixos-25.11` in `flake.nix`. The flake brings
in `home-manager/release-25.11` (also pinned), `opencode-bwrap-nix`
(`michalrus`), and `pi.nix` (`lukasl-dev`).

**Overlays (5):**

| Overlay | Adds |
|---------|------|
| `nix/overlays/emacs-extra.nix` | ~15 Emacs recipes (pro-tabs, telega, emcp, http-server, agent-shell, …) + external MELPA packages (embark, eldoc-box) |
| `nix/overlays/opencode-stub.nix` | `opencode` binary from npm, patchelf'd to glibc |
| `nix/overlays/pi-acp.nix` | `piAcp` from `nix/node-packages/pi-acp.nix` |
| `nix/overlays/mirrors.nix` | URL rewriter for `curl.haxx.se`, `astron.com`, `git.kernel.org` |
| `nix/overlays/github-proxy.nix` | Opt-in `NIX_GITHUB_PROXY` |

## Layer 2: Emacs 30 (in Nix)

`emacsPkg = pkgs.emacs30 or pkgs.emacs` — preference for Emacs 30. The
provided package list (see [Reference → defcustom](reference/defcustom.md))
lives in `emacs/core.nix#pro.emacs.providedPackages` and is **58** packages.
They are made visible to Emacs via `EMACSLOADPATH` (computed at build time by
walking every `share/emacs/site-lisp` in the closure).

## Layer 3: AI agents

* **`pi`** — primary CLI agent, from `lukasl-dev/pi.nix`. Its NixOS module
  (`pi.nixosModules.default`) is wired in globally.
* **`opencode`** — npm binary, surfaced through `opencode-stub` overlay.
  Sandboxed variant via `opencode-bwrap-nix` (Home Manager module).
* **`pi-acp`** — `svkozak/pi-acp` v0.0.27 — adapter from `pi` to the Agent
  Client Protocol. Built with `buildNpmPackage` + Node 20.
* **`emcp`** — the bridge from Emacs to MCP. The HTTP server lives in
  `127.0.0.1:38913`. The Emacs package is a fork of
  `codeberg.org/martenlienen/emcp`; the HTTP backend is a fork of his
  `http-server.el`.
* **`gptel`** — the Emacs-side LLM client. Backends are declared in
  `emacs/base/modules/ai-models.json` (4 providers: openrouter, siliconflow,
  aitunnel, plus the user's own).

## Layer 4: Window managers — three, one keyboard

The keyboard map is the same in all three:

| Action | EXWM | Sway | i3 |
|--------|------|------|-----|
| Focus window | `s-h` / `s-j` / `s-k` / `s-l` | `Mod4+h/j/k/l` | `Mod4+h/j/k/l` |
| Move window | `s-H` / `s-J` / `s-K` / `s-L` | `Mod4+Shift+h/j/k/l` | `Mod4+Shift+h/j/k/l` |
| Workspace 1..9 | `s-1`..`s-9` | `Mod4+1`..`Mod4+9` | `Mod4+1`..`Mod4+9` |
| Terminal | `C-c t o` (Emacs vterm) | `Mod4+Return` (foot) | `Mod4+Return` (xterm) |
| App launcher | `s-x` (Emacs consult) | `Mod4+Space` (wofi) | `Mod4+Space` (dmenu) |
| Close window | (Emacs `C-x k 0`) | `Mod4+q` | `Mod4+q` |
| Reload config | `C-x M-c` | `Mod4+Shift+c` | `Mod4+Shift+c` |

The shared EXWM-session launcher is in `emacs/exwm.nix:96-176`. It does
`ssh-agent`, `xset b off`, `xhost +SI:localuser:`, IME env vars,
`xrdb -merge`, `systemd-run --user --scope -p MemoryMax=2G -p CPUQuota=120%`
and `exec emacs`. A `~/.cache/emacs-startup/gdm-exwm.log` is appended with
timestamps and env.

## Layer 5: Privacy & Tor

* `tor` (local service, SOCKS5 on 9050, control 9051, DNS 9053)
* `torsocks`, `obfs4`, `meek`, `snowflake` (via `pro-privacy.nix` ClientTransportPlugin)
* `onionshare`, `nyx`, `dnscrypt-proxy`, `proxychains`, `mullvad-vpn`
* Optional: `i2p` (off by default), `yggdrasil` mesh daemon
* `scripts/pro-tor` toggles `~/.config/pro-tor/env` (mode 0700) which exports
  `ALL_PROXY=socks5h://…`, `NO_PROXY=127.0.0.1,localhost,*.local,.local,::1`

## Layer 6: Dev tooling

* LSP: `pyright`, `jdtls`, `rust-analyzer`, `gopls`, `bash-language-server`
* Haskell: `ghc`, `haskell-language-server`, `cabal-install`, `stack`, `ghcid`,
  `hlint`, `fourmolu` (see `modules/pro-haskell.nix`)
* Docker: `lazydocker`, `dive`, `ctop`, `trivy`, `hadolint`, `sops`, `age`,
  plus a custom bridge `pro-dev` (`172.20.0.0/16`) in `modules/pro-docker.nix`
* Templates: `templates/microservice/` (alpine + tini + SOPS + just recipes)

## Versions and pins

| Component | Version | Where |
|-----------|---------|-------|
| NixOS | `nixos-25.11` | `flake.nix#inputs.nixpkgs.url` |
| home-manager | `release-25.11` | `flake.nix#inputs.home-manager.url` |
| Linux kernel | `linuxPackages_6_6` (default) / `linuxPackages_latest` (desktop) | `configuration.nix:113`, `hosts/desktop/configuration.nix:26` |
| Emacs | 30 (preferred) | `flake.nix:56` |
| pi | (upstream pinned) | `flake.nix#inputs.pi.url` |
| opencode | 1.17.13 | `nix/overlays/opencode-stub.nix` |
| telega | 0.8.632 | `nix/emacs-recipes/telega.nix` |
| emcp | unstable-2026-06-11 | `nix/emacs-recipes/emcp.nix` |
| pi-acp | 0.0.27 | `nix/node-packages/pi-acp.nix` |
| tree-sitter grammars | 0.13.49 | `nix/treesitter-grammars.nix` |
