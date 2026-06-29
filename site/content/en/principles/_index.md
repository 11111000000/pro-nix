+++
title = "Principles"
sort_by = "weight"
template = "section.html"

[extra]
tldr = "Five cross-cutting principles: declarative, idempotent, single source of truth, opinionated + transparent, layered & composable. They govern every commit in the repo."
+++

The repo has no design doc, no architecture diagram, and no RFC process. It has
**five principles** that anyone touching the code is expected to keep. They are
short, easy to remember, and almost always apply.

## 1. Declarative everywhere

If a state can be expressed as a value, it is a value. System services, Emacs
variables, fontconfig defaults, agent MCP servers — all are written down as data
and read at activation time. The only side effects in the repo are activation
scripts and `writeShellScriptBin` wrappers; everything else is a `mkOption` or a
`defcustom`.

> **Test it yourself.** Pick any module in `modules/`. You should be able to
> tell, without running the code, what packages it installs, what services it
> starts, and what files it writes.

## 2. Idempotent + soft-reload

Every operation must be safe to repeat. `just switch` does not care whether it
has been run before; `pro/reload-config` (C-x M-c) does not care how many times
you have already reloaded; `home.activation.pro-agent-configs-deploy` will not
overwrite your local edits.

The most important consequence: the **soft-reload contract**. Modules that own
persistent state (child frames, background processes, cached values) register
teardown functions on `pro--after-reload-hook`. After a soft reload, those
modules re-create their state from the freshly loaded code — see
`emacs/base/modules/pro-reload.el:11-22` for the contract.

## 3. Single Source of Truth

Three facts have exactly one canonical place each:

| Fact | Source of truth |
|------|----------------|
| Host list and roles | `modules/pro-hosts.nix#pro.hosts` |
| Global key bindings | `emacs-keys.org` (org-table, parsed at runtime) |
| Per-host secrets and overrides | `local.nix` (gitignored) |

Everything else is **derived**. The generated `ssh_config.d/pro.conf` is derived
from `pro.hosts`. The `emcp` MCP port is derived from `pro-emcp.el`. The
`chromium` `MemoryMax` slice is derived from `system-package-sets-desktop-heavy.nix`.
No duplication. If you see the same fact in two places, that is a bug.

## 4. Opinionated + transparent

When the project makes a choice, the choice is visible:

* `pro-ui-default-theme = 'tao-yang` (light, yang)
* `pro-ai-backend = 'aitunnel` (with openrouter + siliconflow as alternatives)
* `pro-tor local` (the only mode that survives a flaky hotel Wi-Fi)
* `services.headscale.enable = true` on `desktop`, `lib.mkForce false` elsewhere
* `pro-ui-font-family = "Aporetic Sans Mono"` (with DejaVu fallback)

The opinion is enforced by `lib.mkDefault` (so hosts can override per machine)
or by being inside a single `composition.nix` (so a host opt-out is a one-line
change in `hosts/<host>/composition.nix`). The transparency is provided by
comments in the module headers (see any `modules/pro-*.nix` for the
"Назначение / Цель / Контракт / Proof" template).

## 5. Layered & composable

Three layers, each one independently useful:

* **System layer.** Pure NixOS. You can use the repo without ever opening Emacs.
* **Emacs layer.** Pure Emacs. The Nix system can be replaced and `pro-*.el` will
  still load.
* **Agent layer.** Pure agent configs. `local-templates/{pi,opencode}/` is a
  complete set of dotfiles that an agent can run on a non-NixOS host.

Within each layer, layers again. The Emacs bootstrap has four phases
(`early-init.el` → `init.el` → `site-init.el` → `pro-emacs-base-start`).
The NixOS flake has `mkHost` (full config) and `mkVmHost` (minimal baseline
without `configuration.nix`). The network has three independent layers
(LAN-mDNS, mesh, SSH-нейминг) that compose without depending on each other.

## The five principles in one sentence

> **A fact lives in exactly one place; the value is always derived; the
> derivation is always idempotent; the choice is always visible; the layers
> always compose.**
