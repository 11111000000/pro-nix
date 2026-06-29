+++
title = "just recipes"
template = "page.html"
weight = 2

[extra]
tldr = "30+ just recipes in 5 clusters: build/switch, submodules, agents, tests, Docker. All use git+file://...?submodules=1."

[[extra.next]]
title = "Submodules"
url = "/workflow/submodules/"

[[extra.next]]
title = "Soft-reload"
url = "/workflow/reload/"
+++

# just recipes

`justfile` is the **canonical command surface**. There are ~30
recipes in five clusters. Below is the full list with what each
does and when to use it.

## Cluster 1: build / switch

| Recipe | Command | When |
|--------|---------|------|
| `just build <host>` | `sudo nixos-rebuild build --flake "git+file://$(pwd)?submodules=1#{{HOST}}"` | Build only, no apply. Use when validating a change. |
| `just switch <host>` | `scripts/switch.sh "{{HOST}}"` | Apply. The most common command. Runs `helper-switch.sh` under the hood. |
| `just switch <host> update-submodules` | Same + `update-submodules` flag | Refresh submodules from remote before building. |
| `just switch <host> sync` | Same + `sync` flag | Alias for `update-submodules`. |
| `just test <host>` | `sudo nixos-rebuild test --flake "git+file://$(pwd)?submodules=1#{{HOST}}"` | Apply for the duration of the next boot, then revert. Safer than `switch` for risky changes. |
| `just flake-check` | `nix flake check "git+file://$(pwd)?submodules=1"` | Syntax + check types. Fast (~30 s). |
| `just check-all` | `nix run .#check-all` | Build all 3 full hosts. Slow (10-30 min). |
| `just check-fast` | `./tools/holo-verify.sh --help >/dev/null` | Sanity check that `holo-verify` runs. |
| `just check-docs` | `./tools/holo-verify.sh --help >/dev/null` | Same (placeholder for future docs-only check). |
| `just check-elisp` | `./tools/holo-verify.sh elisp` | All `pro-*.el` modules parse and load. |

## Cluster 2: submodules

| Recipe | Command | When |
|--------|---------|------|
| `just sync-submodules` | `scripts/sync-submodules.sh` | Refresh all submodules from remote. Sequential (15 submodules × ~11 s). |
| `just submodules-ssh` | `scripts/submodules-ssh.sh` | Convert all HTTPS submodule URLs to SSH. Use if you have write access. |
| `PRO_NIX_NO_SUBMODULE_UPDATE=1 just switch <host>` | Escape hatch | Skip submodule policy entirely. |

`just switch` itself **does not** refresh submodules from remote by
default. It initializes them only if they are uninitialized. If you
want a refresh, use the `update-submodules` flag.

## Cluster 3: agents

| Recipe | Command | When |
|--------|---------|------|
| `just deploy-agents` | `scripts/deploy-agent-configs.sh && scripts/install-pi-packages.sh` | Deploy templates + npm packages. No `nixos-rebuild`. |
| `just install-pi-packages` | `scripts/install-pi-packages.sh` | Just the npm packages. |
| `just switch-with-agents <host>` | deploy + install + switch, in order | The full cycle. Use on a fresh machine. |
| `just update-pi-version` | `scripts/update-pi-version.sh` | Bump the `pi` input in `flake.lock`. Dry-run by default. |

`deploy-agents.sh` is `copy_if_missing` — safe to run repeatedly. To
force a re-deploy of a specific file, `rm` it first, then run the
script.

## Cluster 4: tests

| Recipe | Command | When |
|--------|---------|------|
| `just headless-tty` | `./scripts/emacs-verify.sh tty` | TTY headless smoke. |
| `just headless-xorg` | `./scripts/emacs-verify.sh xorg` | Xvfb headless smoke. |
| `just headless` | `./scripts/emacs-verify.sh both` | Both. |
| `just headless-tests` | `./scripts/test-emacs-headless.sh both` | Full headless ERT suite. |
| `just headless-parse` | `./scripts/parse-emacs-logs.sh` | Pretty-print latest `*test*` / `[pro-emacs]` / ERT / error lines. |
| `just headless-report` | `./scripts/emacs-headless-report.sh` | Print date + hostname + Emacs version + tail of last `run.log`. |
| `just logs-latest` | `./scripts/emacs-headless-report.sh` | Alias for `headless-report`. |
| `just emacs-verify` | `./scripts/emacs-verify.sh both` | Alias for `headless`. |
| `just network-contract` | `./tests/contract/pro-network-01.sh` | 5 checks on the network layer. |
| `just emacs-sync` | `./scripts/dev-emacs-sync.sh` | Sync the portable Emacs profile to `~/.config/emacs`. |

## Cluster 5: Docker

The Docker recipes are aliases around `lazydocker` and the Docker
CLI. They assume the user is in the `docker` group (set by
`pro-users.nix`).

| Recipe | Command | When |
|--------|---------|------|
| `just d` | `lazydocker` | TUI: ps / logs / exec / restart / prune. |
| `just dl <name>` | `docker logs -f --tail 100 <name>` | Tail logs. |
| `just dsh <name> [cmd]` | `docker exec -it <name> <cmd>` (default `sh`) | Shell into a container. |
| `just dr <name>` | `docker restart <name> && sleep 1 && docker logs --tail 30 <name>` | Restart + first 30 lines. |
| `just dprune` | `docker system prune -f` + image + network | Cleanup. **Destructive.** |
| `just dscan <image> [severity]` | `trivy image --severity <severity> --no-progress <image>` | Vulnerability scan. |
| `just dlint [<dockerfile>]` | `hadolint <dockerfile>` (default `Dockerfile`) | Lint a Dockerfile. |
| `just dup` | `docker compose up -d` | Compose up. |
| `just ddown` | `docker compose down` | Compose down. |
| `just dps` | `docker compose ps` | Compose ps. |
| `just dclogs` | `docker compose logs -f --tail 50` | Compose logs. |

## Cluster 6: site (this site)

| Recipe | Command | When |
|--------|---------|------|
| `just site-serve` | (manual `zola serve` in `site/`) | Local preview with live reload. |
| `just site-build` | `nix build ".#site"` | Produce the final static output. |
| `just site-regen` | `scripts/site-regen.sh` | Regenerate every auto-gen page. |

## Bootstrap recipes

| Recipe | Command | When |
|--------|---------|------|
| `just install` / `just install-nixos` | `./bootstrap/install.sh` | Bootstrap script. |
| `just install-emacs` / `just install-plain` | `./scripts/dev-emacs-sync.sh` | Sync Emacs to `~/.config/emacs`. |

## Aliases

`switch` and `switch.sh` are aliases (the just recipe calls the
script). `check-fast` and `check-docs` are placeholders for future
docs-only fast check (currently they are no-ops).

## How the recipes resolve

`just` looks up recipes in `justfile:1-164`. The shell is set to
`bash -eu -o pipefail -c` for safety. Recipes can use any of:

* `nix` (subprocess)
* `sudo` (where required)
* `bash` (for in-recipe logic)
* Any of the just variables: `{{HOST}}`, `{{FLAGS}}`, `{{NAME}}`, `{{CMD}}`, `{{IMAGE}}`, `{{SEVERITY}}`, `{{DOCKERFILE}}`.

## Adding a new recipe

1. Decide the cluster (build / submodules / agents / tests /
   docker / site / bootstrap).
2. Add the recipe to `justfile` in the matching section.
3. Document it here in the table above.
4. Add a one-liner test to `tests/contract/unit/` if the recipe
   has any non-trivial side effect.

## See also

* [Quick start](workflow/quickstart.md) — the end-to-end onboarding flow.
* [Submodules](workflow/submodules.md) — the SSH/HTTPS policy.
* [Troubleshooting](workflow/troubleshoot.md) — when a recipe misbehaves.
