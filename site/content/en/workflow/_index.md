+++
title = "Workflow"
sort_by = "weight"
template = "section.html"

[extra]
tldr = "Day-to-day operations: just recipes, submodules policy, agent deployment, soft-reload, per-host checklist, troubleshooting."
+++

Most of what you do in the repo goes through `just`. The recipes are in
`justfile:1-164` and group into five clusters.

## 1. Build / switch

```bash
just switch <host>           # nixos-rebuild switch, post-fix emacs ownership, deploy bin/
just switch-with-agents <host>   # same + deploy-agent-configs + install-pi-packages
just build <host>            # nixos-rebuild build (no apply)
just test <host>             # nixos-rebuild test (offline activation)
just flake-check             # nix flake check with submodules=1
just check-all               # nix run .#check-all — builds all 3 full hosts
```

`just switch` runs `scripts/helper-switch.sh`, which:

* Uses `git+file://$PWD?submodules=1` (path: and . don't include submodules)
* Decides submodules policy: `init` if uninitialized, `skip` if present, `update` only on `--update-submodules` / `sync`
* Pipes `nixos-rebuild switch` through `tee` to `/tmp/switch-<epoch>.log`
* On success, `chown -R $USER` for `~/.config/emacs`, `~/.local/state/pro-emacs`, `~/.cache/pro-emacs` (because sudo-activation can leave root-owned files there)
* Deploys `bin/*` to `~/bin` and adds `~/bin` to `~/.profile` PATH

## 2. Submodules

The repo uses 11 git submodules, all HTTPS by default. SSH is opt-in per host.

```bash
git submodule update --init --recursive   # first time
just sync-submodules                       # refresh all from remote (sequential, 20s/10s timeouts)
just submodules-ssh                        # convert all HTTPS to SSH (for users with write access)
```

`just switch` does **not** refresh submodules from remote by default; it
initializes them only if they are uninitialized. To force a refresh before
build, use `just switch <host> update-submodules`. To skip the policy entirely,
set `PRO_NIX_NO_SUBMODULE_UPDATE=1`.

## 3. AI agent deployment

```bash
just deploy-agents            # copy local-templates/{pi,opencode}/* into $HOME
just install-pi-packages      # pi install npm:<pkg> for every package in settings.json
just switch-with-agents <host>    # chain: deploy-agents + install-pi-packages + switch
```

`deploy-agent-configs.sh` is **copy-if-missing** — it never overwrites a user's
local edits. To force an update, `rm ~/.config/opencode/opencode.json && just
deploy-agents`. The script also creates
`~/.local/share/pro-nix/load-agent-env.sh` and appends a marker line to
`~/.profile` so shell sessions pick up `AITUNNEL_KEY`, `OPENROUTER_KEY`, etc.,
from `~/.authinfo` (or `~/.authinfo.gpg`).

## 4. Emacs soft-reload

Inside Emacs:

```
C-x M-c            M-x pro/reload-config       quick reload (modules in place)
C-u M-x pro/reload-config                      full reload (re-evals site-init + all modules)
M-x pro-keys-reload                            reparse emacs-keys.org
M-x pro-keys-report-pending                    list bindings waiting on a package
```

See [Architecture → Emacs bootstrap](architecture/_index.md) for the
four-phase model. See `emacs/base/modules/pro-reload.el:11-22` for the
module-author contract.

## 5. Tests

```bash
just flake-check         # nix flake check
just network-contract    # tests/contract/pro-network-01.sh (5 checks)
just headless-tests      # run emacs headless ERT suite
just headless-report     # tail the latest run log
```

There are five layers of tests:

1. **`nix flake check`** — syntactic and type-level checks.
2. **Slow VM tests** — gated by `PRO_NIX_RUN_SLOW_CHECKS=1`; spin up a NixOS VM
   and verify it boots / activates cleanly.
3. **Contract tests** — `tests/contract/*` (sh + el + spec files) — assert
   structural properties (pro.hosts has 4 entries, headscale only enabled on
   desktop, EMCP port is 38913, …).
4. **Unit tests** — `tests/contract/unit/*` (10 small scripts).
5. **GUI smoke** — `tests/gui/gui-smoke.el` under Xvfb.

## 6. Per-host checklist

After a fresh `just switch`, do these per host:

**desktop:**

```bash
# 1. SSH keys (one-time, see README §1)
# 2. Avahi: getent hosts desktop.local
# 3. NFS export: install -d -m 2775 -o root -g pro /srv/nfs
# 4. headscale: cp /var/lib/headscale/noise_private.key /etc/headscale/
# 5. headscale users create az; preauthkeys create --user az --reusable --expiration 24h
# 6. systemctl status headscale avahi-daemon tor
```

**cf19 / huawei:**

```bash
# 1. SSH keys
# 2. getent hosts desktop.local   (must resolve)
# 3. ls /mnt/desktop             (≤ 3 s even if desktop is offline)
# 4. M-x pro/reload-config        (picks up freshly activated modules)
# 5. C-c a  M-x pro-ai-open-entry (gptel backend reachable)
```

**vm:**

```bash
# 1. SSH keys
# 2. systemctl --no-pager --failed
# 3. mount | grep /mnt/desktop
# 4. nix flake check  (sanity)
```

## 7. Troubleshooting

| Symptom | Where to look |
|---------|---------------|
| `Permission denied (publickey)` on `ssh desktop` | `~/.ssh/authorized_keys` on the server; `~/.ssh/id_ed25519` on the client |
| `getent hosts desktop.local` returns nothing | `systemctl restart avahi-daemon`; verify `nss-mdns` is in `/etc/nsswitch.conf` |
| `ls /mnt/desktop` hangs > 3 s | `grep /mnt/desktop /etc/fstab` should show `timeo=10,retrans=1,x-systemd.mount-timeout=3,nofail` |
| `Cannot open load file "some-pkg"` in Emacs | `git submodule update --init --recursive` |
| `headscale: noise key regenerated, all sessions lost` | Backup `noise_private.key` from `/var/lib/headscale/` into `local.nix` |
| `nixos-rebuild switch` hangs at `mount` | NFS mount without `nofail`. Add `x-systemd.mount-timeout=1` per-mount |
| `emcp` not visible to pi | `emacsclient -e '(pro-emcp-server-start)'` then `pi -p 'mcp({})'` |
| `*.el` reload warns "not owned by current user" | `sudo chown -R $USER ~/.config/emacs` (helper-switch.sh does this on success) |
| Surface-lint complains about a module | Add the four required sections to the module header: Назначение / Цель / Контракт / Proof |

## 8. Editing the repo

Always:

1. Read [Conventions](conventions/_index.md) — commit types, mkForce rules,
   anti-patterns, dead-code detectors.
2. Run `nix flake check` before pushing.
3. Run `just network-contract` if you touched a network module.
4. Run `just headless-tests` if you touched an Emacs module.
5. Fill the Change-Gate (`Intent:` / `Pressure:` / `Surface:` / `Proof:`) in the
   PR body.
