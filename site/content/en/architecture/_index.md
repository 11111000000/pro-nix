+++
title = "Architecture"
sort_by = "weight"
template = "section.html"

[extra]
tldr = "Three layers (NixOS / Emacs / agents) with a four-phase bootstrap in Emacs, a flake with two host-constructors, and a three-layer network model (LAN mDNS + headscale mesh + SSH-нейминг)."
+++

The architecture is best read top-down: from the flake, into the modules, into
the composition files, into the host configs. Emacs is a sibling layer with its
own four-phase bootstrap. The agent layer is a thin shell of templates that
deploy into `$HOME`.

## The Nix flake

```nix
# flake.nix: simplified
inputs = {
  nixpkgs.url          = "nixpkgs/nixos-25.11";
  home-manager.url     = "github:nix-community/home-manager/release-25.11";
  opencodeBwrap.url    = "github:michalrus/opencode-bwrap-nix";
  pi.url               = "github:lukasl-dev/pi.nix";
  systems.url          = "github:nix-systems/default";
};

outputs = { ... }: {
  nixosConfigurations = {
    cf19    = mkHost [...];
    huawei  = mkHost [...];
    desktop = mkHost [...];
    vm      = mkVmHost [...];   # minimal baseline, no configuration.nix
  };
  checks.${system}    = { default = huawei.config.system.build.toplevel; ... };
  apps.${system}      = { check-all = ...; site-serve = ...; site-regen = ...; };
  devShells.${system} = { default = ...; };  # has emacs-pro wrapper
  packages.${system}  = { site = ...; };
};
```

Two host constructors:

* `mkHost` — full `configuration.nix` + `modules/searxng.nix` + global
  (`pi.nixosModules.default`, `modules/ssh-agent.nix`) + per-host.
* `mkVmHost` — minimal baseline: `packages-runtime.nix` + `tty-console.nix`
  + `searxng.nix` + per-host. No `configuration.nix` import. This is why
  `headscale.enable` does not exist in the `vm` evaluation.

## The NixOS module tree

50+ files in `modules/`, grouped by role:

| Pattern | What it is | Example |
|---------|-----------|---------|
| `pro-*.nix` | Regular NixOS modules | `pro-network.nix`, `pro-ssh-clients.nix`, `pro-emacs-rescue.nix` |
| `session-*.nix` | Window managers / display managers | `session-i3.nix`, `session-sway.nix`, `session-cinnamon.nix` |
| `system-*.nix` | Low-level policies | `system-boot.nix` (kernel, GRUB) |
| `system-package-sets-*.nix` | **Not modules** — functions `{ pkgs }: { fooPackages = [...]; }` imported from `hosts/*/composition.nix` | `system-package-sets-runtime.nix`, `system-package-sets-exwm.nix` |
| `nix-*.nix` | Custom packages / units | `nix-cuda-compat.nix` (overlay only) |

The **composition files** are the trick. A host is not a module; it is a set
of `environment.systemPackages` plus a few `mkDefault true` markers. See
`hosts/desktop/composition.nix:1-16` for the desktop example.

## The Emacs bootstrap

Four phases, each in its own file:

| Phase | File | What it does |
|-------|------|--------------|
| 1 | `early-init.el` | Disables `package-enable-at-startup`, sets load-path, GUI hygiene, best-effort treesit |
| 2 | `init.el` | Sets `user-emacs-directory`, `custom-file`, loads `pro-compat`/`pro-packages`, calls `pro-emacs-base-start` |
| 3 | `site-init.el` | Module manifest, resolver, key loader, `provided-packages.el` (Nix facts) |
| 4 | `pro-emacs-base-start` | Loads all 60 modules, then `pro-keys-apply-pending` |

The **soft-reload contract** lives in `pro-reload.el`:

```elisp
;; Module authors register teardown on pro--after-reload-hook
(pro/after-reload #'my-reset-fn)

;; C-x M-c     (or M-x pro/reload-config)   reloads in place
;; C-u M-x pro/reload-config                re-evals site-init.el + all modules
```

The contract is described in the file header (`emacs/base/modules/pro-reload.el:11-22`):
top-level forms must be idempotent, modules that own persistent state must
re-create it on `pro--after-reload-hook`.

## The three-layer network

| Layer | Module | Transport | Scope |
|-------|--------|-----------|-------|
| **LAN mDNS** | `pro-network.nix` (Avahi + nss-mdns) + `pro-peer.nix` (publishes `_ssh._tcp`) | UDP 5353 multicast | One L2 segment |
| **Mesh** | `headscale.nix` (control plane) | WireGuard (userspace via headscale) | Anywhere with internet |
| **SSH-нейминг** | `pro-ssh-clients.nix` (renders `ssh_config.d/pro.conf`) | SSH on top of whichever candidate wins | Always (whichever layer answers first) |

The SSH layer is the only one with a real fallback. `pro-ssh-clients.nix`
generates one `Host` block per host in `pro.hosts`, with the candidates
tried in order: `tailnet-fqdn` → `tailnet-short` → `<name>.local` → `addr` →
`onion` (through torsocks). The first reachable one wins. Each candidate has
its own `ConnectTimeout`, so a dead `.local` does not block a working
tailnet-FQDN.

## The agent stack

```
$HOME/.pi/agent/         (deployed by pro-agent-configs.nix)
├── settings.json         # defaultProvider, defaultModel, npm packages
├── models.json           # 4 providers × 24+ models
├── mcp.json              # emcp + chrome-devtools
├── skills/emacs-emcp/    # SKILL.md (operator guide for emcp)
├── skills/safe-bash/     # SKILL.md (cross-platform shell safety)
└── extensions/pi-permission-system/config.json   # deny-by-pattern

$HOME/.config/opencode/
├── opencode.json         # same 4 providers
├── tui.json              # plugin: []
└── skills/emacs-emcp/SKILL.md

$HOME/.local/share/pro-nix/load-agent-env.sh
    reads ~/.authinfo, exports {AITUNNEL,OPENROUTER,OPENAI,MISTRAL,MINIMAX,DEEPSEEK}_KEY
```

MCP tools are exposed to the agent two different ways:
- In **pi**: through a proxy tool `mcp({tool: ..., args: ...})`
- In **opencode**: as direct tools, e.g. `emcp_apropos`

The `emacs-emcp` skill is the same Markdown in both places, with the only
difference being the YAML frontmatter (pi has it, opencode does not).

## Recap

Three independent layers, each with a single source of truth:

* **Nix** — flake → modules → composition → host.
* **Emacs** — early-init → init → site-init → pro-emacs-base-start.
  **64 `pro-*.el` modules** are loaded by default.
* **Agents** — `local-templates/` → `home.activation.pro-agent-configs-deploy`
  → `~/.pi/agent/`, `~/.config/opencode/`, plus `~/.local/share/pro-nix/load-agent-env.sh`.

The site you are reading is itself a fourth layer, also declarative: source in
`site/`, build by `nix build '.#site'`, deploy by GitHub Actions to
`gh-pages` and `surge.sh`.
