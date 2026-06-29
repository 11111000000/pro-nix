+++
title = "Submodules"
template = "page.html"
weight = 3

[extra]
tldr = "11 submodules, HTTPS by default, switch with just submodules-ssh. just switch does not refresh from remote unless --update-submodules / sync. Helper script: scripts/sync-submodules.sh (sequential, timeouts)."

[[extra.next]]
title = "Agents"
url = "/workflow/agents/"

[[extra.next]]
title = "Per-host checklist"
url = "/workflow/per-host/"
+++

# Submodules

The repo pulls in **11 git submodules** for Emacs packages and
upstream forks. They are configured in `.gitmodules` with HTTPS
URLs by default; SSH is opt-in per host.

## The 11 submodules

| Name | Path | URL | What |
|------|------|-----|------|
| `pro-tabs` | `submodules/pro-tabs` | github.com/gnu-emacs-ru/pro-tabs | Unified Emacs tab-bar + tab-line with icons |
| `carriage` | `submodules/carriage` | github.com/gnu-emacs-ru/carriage | "Code knitting" workflow for Org |
| `emcp` | `submodules/emcp` | codeberg.org/martenlienen/emcp | Emacs MCP server (HTTP on 38913) |
| `telega.el` | `submodules/telega.el` | github.com/zevlg/telega.el | Telegram client for Emacs (TDLib-based) |
| `agent-shell` | `submodules/agent-shell` | github.com/11111000000/agent-shell | Emacs shell for ACP-speaking agents |
| `acapella` | `submodules/acapella` | github.com/gnu-emacs-ru/acapella | A2A-protocol Emacs client |
| `atlas` | `submodules/atlas` | github.com/gnu-emacs-ru/atlas | Universal project map (APM v2 format) |
| `tao-theme` | `submodules/tao-theme` | github.com/11111000000/tao-theme-emacs | tao-yang (light) and tao-yin (dark) themes |
| `shaoline` | `submodules/shaoline` | github.com/11111000000/shaoline | Minimalist mode-line |
| `agent-shell-hud` | `submodules/agent-shell-hud` | github.com/11111000000/agent-shell-hud | Multilingual HUD overlay for agent-shell |
| `acp` | `submodules/acp` | github.com/xenodium/acp.el | Emacs implementation of the Agent Client Protocol |

See [Reference → Submodules](reference/submodules.md) for the full
auto-generated catalogue.

## The HTTPS-by-default policy

`.gitmodules` has HTTPS URLs everywhere. This is so that **anyone
can clone without an SSH key** — including CI runners, containers,
and one-off development environments.

The trade-off: HTTPS users can read but cannot push to the upstream
forks. For users with write access, `just submodules-ssh` converts
all URLs to SSH form.

## The submodule policy during `just switch`

`just switch <host>` runs `scripts/helper-switch.sh`, which
implements a **three-mode** policy:

| Mode | When | What |
|------|------|------|
| `init` | Any submodule is uninitialized (detected via `git submodule status \| grep '^-'`) | `git submodule update --init --recursive` |
| `skip` | All submodules are initialized | Use as-is. **No fetch, no merge, no remote touch.** |
| `update` | The user passed `update-submodules` or `sync` as the `FLAGS` arg | `scripts/sync-submodules.sh` (refresh from remote, sequential, with timeouts) |

The default is `skip` — `just switch` does **not** touch the
network for submodules. To force a refresh, pass the flag:

```bash
just switch huawei update-submodules
just switch cf19 sync
```

To skip the policy entirely (escape hatch):

```bash
PRO_NIX_NO_SUBMODULE_UPDATE=1 just switch huawei
```

## Why sequential, not parallel

`scripts/sync-submodules.sh` does **not** use `git submodule
foreach` in the background. It runs sequentially, with a 20-second
fetch timeout and a 10-second merge timeout per submodule. The
reason: parallel fetches against GitHub's anonymous API hit rate
limits within minutes. Sequential is slower worst case (165 s for
15 submodules × 11 s each) but reliable.

## What happens when a fetch fails

`sync-submodules.sh` does **not** fail the build when a fetch
fails. It logs `WARNING: fetch failed for <submodule>`, skips the
update for that submodule, and continues. The reason: the Nix
recipes read the **local** `submodules/<name>`, not the remote, so
a previous valid commit/submodule-pair remains buildable. The user
gets a working build even if one upstream is down.

## The dirty-submodule check

`sync-submodules.sh` does a dirty check **before** any fetch:

```bash
git submodule foreach 'git diff --quiet HEAD'
```

If any submodule has uncommitted changes, the script fails loudly.
This protects against "I edited a submodule, then ran `just
sync-submodules`, and the script stomped my work" — the dirty
check makes the user fix the dirty submodule first.

## Manual submodule operations

```bash
# Just init
git submodule update --init --recursive

# Refresh one submodule from remote
git submodule update --remote --merge submodules/agent-shell

# Refresh all submodules from remote
just sync-submodules
# or
git submodule update --remote --merge

# Switch one submodule to a fork
git config submodule.submodules/agent-shell.url git@github.com:YOUR_USER/agent-shell.git
git submodule sync
```

## HTTPS → SSH

`just submodules-ssh` runs `scripts/submodules-ssh.sh`. The script:

1. Backs up `.gitmodules` to `.gitmodules.backup.<ts>`.
2. `trap EXIT` to restore on error.
3. Reads the URL for each submodule.
4. For `github.com` URLs, converts `https://github.com/<owner>/<repo>.git`
   to `git@github.com:<owner>/<repo>.git`.
5. For `codeberg.org` URLs, converts to `git@codeberg.org:<owner>/<repo>.git`.
6. Writes the new URL via `git config -f .gitmodules`.
7. `git submodule sync --recursive` to update the local config.
8. `git submodule update --remote --merge` to actually pull from the
   new URL.

To revert to HTTPS:

```bash
# Find the latest backup
ls -t .gitmodules.backup.* | head -1

# Restore
cp $(ls -t .gitmodules.backup.* | head -1) .gitmodules
git submodule sync
git submodule update --remote --merge
```

## Why `git+file://$(pwd)?submodules=1` matters

`flake.nix` references all submodules through recipes in
`nix/emacs-recipes/*.nix`. Each recipe has
`src = ../../submodules/<name>`. When `nix` evaluates the flake, it
captures the source from the local path — **but only if the flake
URL is `git+file://...` with `?submodules=1`**. The `path:` and `.`
shorthands do **not** include submodules in the captured source,
so the recipes fail with "path does not exist".

This is why every `just` recipe that runs `nix` (build, switch,
test, flake-check, check-all) uses the explicit URL. The
`helper-switch.sh` script sets it once at the top:

```bash
FLAKE_REF="git+file://$PWD?submodules=1"
```

The `just` recipes that need to set it inline do so too:

```bash
nix build ".#nixosConfigurations.cf19.config.system.build.toplevel"  # uses . → FAILS for submodules
nix build "git+file://$(pwd)?submodules=1#nixosConfigurations.cf19.config.system.build.toplevel"  # works
```

`nix run .#check-all` is an exception — it is an `app`, and the
`program` is a shell script that sets the URL internally. The
recipe lives at `flake.nix:137-146` and is safe to call as
`nix run .#check-all`.
