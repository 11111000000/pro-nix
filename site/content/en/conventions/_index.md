+++
title = "Conventions"
sort_by = "weight"
template = "section.html"

[extra]
tldr = "Governance: commit types, mkForce vs mkDefault, Change-Gate for PRs, dead-code detectors, anti-patterns."
+++

The repo has no formal RFC process. It has **conventions** that everyone — human
or agent — is expected to follow. Each convention is short, has a reason, and
has at least one `tests/contract/*` check behind it.

## Commits

Format: `type: short description`, one logical change per commit.

| Type | Use for |
|------|---------|
| `nix` | NixOS modules, flake, host configs |
| `pkg` | `system-package-sets-*` additions or removals |
| `emacs` | `.el` files, key bindings, sites |
| `keys` | `emacs-keys.org` |
| `fix` | Bug fix in any layer |
| `ops` | Scripts, CI, dev tooling |
| `site` | This site (`site/content/`, `site/templates/`) |
| `chore` | Cleanup, refactoring, docs |

Not mixed: `nix: refactor pro-nfs and also add EXWM urxvt toggle` is two commits
(`nix: refactor pro-nfs` + `emacs: add EXWM urxvt toggle`).

## mkForce vs mkDefault vs plain

Three priorities for `environment.systemPackages`:

```nix
# Plain assignment (default priority 100, lists concat)
environment.systemPackages = with pkgs; [ vim git ripgrep ];

# mkDefault (priority 100, but explicit "this is the default")
environment.systemPackages = lib.mkDefault (with pkgs; [ vim ]);

# mkForce (priority 50, wins over plain + mkDefault)
environment.systemPackages = lib.mkForce (with pkgs; [ neovim ]);
```

**Rules:**

* **Plain assignment** is for **mandatory** packages — the module asserts they
  must be in the system closure. Most `pro-*.nix` modules use this.
* **`lib.mkDefault`** is for **defaults** that the user (or another module) can
  override without conflict.
* **`lib.mkForce`** is for **host-specific overrides** — used in `hosts/*/`
  to say "this host deliberately does not want what the global module gives
  it". The classic example is `headscale.enable = lib.mkForce false` on
  `cf19` / `huawei`.

A **common mistake** is `lib.mkDefault` for a *mandatory* package list. Because
`lib.mkDefault` is itself a priority-100 assertion, any plain assignment in
another module silently replaces it, and the packages disappear. The lint
`tools/mkforce-lint.sh` counts occurrences; if you see `mkDefault` for a
package list, push back.

## Change-Gate (PR template)

Every PR body must contain four fields:

```markdown
Intent: [одной строкой опишите цель изменения]
Pressure: [Bug | Feature | Debt | Ops]
Surface impact: (none) | touches: <SURFACE item(s)> [FROZEN/FLUID]
Proof: tests: <команды или файлы, подтверждающие изменение>
```

* **Intent** — what you are trying to achieve, in one sentence.
* **Pressure** — is this a bug fix, a new feature, a refactor, or operations?
* **Surface** — which public surface (NixOS option, Emacs defcustom, key
  binding) does it touch? Mark `[FROZEN]` for stable contracts (any change
  needs migration notes) and `[FLUID]` for in-progress work.
* **Proof** — what command or test confirms the change works?

`actions/check-change-gate/action.sh` enforces this. Initially the workflow
returns exit 78 (BSD `EX_CONFIG`, non-blocking) for missing fields, so the
project rolls out the gate without breaking existing PRs. The intent is to
flip it to a blocking check later.

## Dead-code detectors

The repo uses several signals to spot modules that should be removed:

* The module contains `placeholder`, `заглушка`, `stub`, `not populated yet`,
  `not implemented`, or `WIP` in its description.
* `environment.systemPackages = with pkgs; [ ];` (empty).
* The module body is `lib.mkIf false { ... }`.
* `sha256 = "0000…000"` in any `fetchurl` / `fetchFromGitHub` / `fetchTarball`.
* `submodule { options = {}; }` with no fields.
* `enable = false;` by default and `mkIf cfg.enable` wraps the entire body.
* The file is imported but none of its public attributes are referenced.

The ritual before deleting:

```bash
rg -l "<filename>"          # direct imports
rg "<attributeName>"        # usages of public exports
nix-instantiate --parse <each file we touch>
```

## Anti-patterns

Things you will see in the code, but should not add to:

* ❌ `lib.mkDefault` for mandatory package lists.
* ❌ `services.resolved.llmnr = "false"` (string) when you mean bool — wait,
  actually it *is* a string enum. This is fine. The anti-pattern is writing
  `llmnr = false` and getting an enum error.
* ❌ `services.tailscale.enable = true` globally — requires an auth key, breaks
  `nixos-rebuild` without a secret. Enable through a future `pro.tailnet`
  module, not globally.
* ❌ `(define-key global-map ...)` in a module. Global bindings belong in
  `emacs-keys.org` only. Use `pro/register-module-keys` if a module wants to
  propose a binding.
* ❌ `nixos-rebuild switch` in CI. CI must be `eval` / `build` / `test` only.
* ❌ `local-set-key` for buffer-local keys inside a `pro-*.el` module's
  top-level forms — that pollutes every buffer. Use mode hooks.
* ❌ Global zoom via `set-face-attribute 'default nil` — it changes the font in
  every buffer. Use `text-scale-adjust` (already wired to `pro-ui-zoom-*`).
* ❌ `path:` URL for a flake that uses submodules. Use
  `git+file://$(pwd)?submodules=1`.
* ❌ Hardcoding IPs in `ssh_config.d/pro.conf`. The generated file uses
  candidate FQDNs from `pro.hosts`; do not bypass it with `pro.hosts.<x>.addr`.

## Module header template

Every `modules/pro-*.nix` is expected to start with:

```nix
# Название: modules/pro-FOO.nix — one-line summary
# Кратко: 1-2 line description
#
# Цель: what this module achieves.
# Контракт: what options it declares, what it does at activation.
# Побочные эффекты: anything the user should know.
# Как проверить (Proof): a runnable command.
# Last reviewed: YYYY-MM-DD
```

`tools/surface-lint.sh` enforces this with `--check-style` / `--enforce-style`.

## Where to look

* `AGENTS.md` — full rule book.
* `tools/holo-verify.sh` — orchestrator.
* `tools/surface-lint.sh` — header sections + Cyrillic presence.
* `tools/mkforce-lint.sh` — counts `lib.mkForce` and `systemPackages`.
* `tools/docs-link-check.sh` — broken internal links.
* `tests/contract/*` — per-convention assertions.
* `tests/contract/unit/*` — short shell scripts.
