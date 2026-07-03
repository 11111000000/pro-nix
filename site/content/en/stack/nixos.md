+++
title = "NixOS layer"
template = "page.html"
weight = 1

[extra]
tldr = "The system layer. NixOS 25.11 pinned, 5 overlays, 50+ modules, mkDefault vs mkForce discipline, composition files, no manual post-install steps beyond `just switch`."

[[extra.next]]
title = "Emacs layer"
url = "/stack/emacs/"

[[extra.next]]
title = "Flake inputs"
url = "/architecture/flake/"
+++

# NixOS layer

The system layer is pure NixOS — no out-of-band package management, no
hand-written files in `/etc/`, no `apt-get install` for system packages.
Everything is either a NixOS option, a custom module in `modules/`, or a
package pulled in by `nix/overlays/`.

## Pin

`nixpkgs/nixos-25.11` in `flake.nix:6`. `home-manager/release-25.11`
follows nixpkgs.

The flake URL **must** be `git+file://$(pwd)?submodules=1` for `nix flake
check`, `nix build`, and `nixos-rebuild`. The `path:` and `.` shorthands
do **not** include submodules in captured source, and the Emacs recipes
read `../../submodules/<name>` as their source.

## Overlays

| Overlay | Adds |
|---------|------|
| `emacs-extra.nix` | ~15 Emacs recipes (pro-tabs, telega, emcp, http-server, agent-shell, …) and external MELPA packages (embark, eldoc-box) |
| `opencode-stub.nix` | `opencode` v1.17.13 from npm, patchelf'd for glibc |
| `pi-acp.nix` | `piAcp` (`nix/node-packages/pi-acp.nix`) |
| `mirrors.nix` | URL rewriter for `curl.haxx.se`, `astron.com`, `git.kernel.org` |
| `github-proxy.nix` | Opt-in `NIX_GITHUB_PROXY` (env) |

`pkgsOverlay = import nixpkgs { overlays = [...]; }` is the **only** way
overlays are applied. Host-specific overlays are not used.

## Modules

See [Reference → NixOS options](reference/options.md) for the 6 modules
that declare `mkOption`. The rest are option-free policy modules.

Composition files (`system-package-sets-*.nix`) are **not** NixOS modules —
they are functions `{ pkgs }: { somePackages = [...]; }` that are
imported from `hosts/*/composition.nix` and `++`d into
`environment.systemPackages`.

## Build / switch

```bash
nix build ".#nixosConfigurations.<host>.config.system.build.toplevel"
nix build ".#nixosConfigurations.{cf19,desktop,vm}.config.system.build.toplevel"
nix run .#check-all    # all three full hosts in one command
```

The slow VM tests are gated by `PRO_NIX_RUN_SLOW_CHECKS=1` — they are
expensive (full NixOS VM boot/activation) and not run by default.

## The "after switch" checklist

`nixos-rebuild switch` activates the system but does **not**:

* deploy `local-templates/{pi,opencode}/*` (use `just deploy-agents` or
  `just switch-with-agents`).
* install `pi` npm packages (use `just install-pi-packages`).
* restore SSH keys (run `ssh-copy-id` per host).
* bring up `tor` service on a host where the user wants a hidden service.

See [Workflow → per-host checklist](workflow/per-host.md) for the full
table.
