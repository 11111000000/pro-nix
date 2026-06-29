+++
title = "Quick start"
template = "page.html"
weight = 1

[extra]
tldr = "git clone, git submodule update --init, just switch <host>. The four hosts are: desktop, cf19, huawei, vm. A fresh machine takes about 30 minutes from clone to boot."

[[extra.next]]
title = "just recipes"
url = "/workflow/just/"

[[extra.next]]
title = "Submodules"
url = "/workflow/submodules/"
+++

# Quick start

A fresh machine, from clone to boot, takes about 30 minutes. The
sequence below assumes Nix is already installed (see
[the NixOS installation guide](https://nixos.org/manual/nixos.org/) or
the [Nix package manager installer](https://nixos.org/download.html)).

## 1. Clone the repo

```bash
git clone https://github.com/11111000000/pro-nix
cd pro-nix
git submodule update --init --recursive
```

The submodule init takes about 5-10 minutes depending on network
speed (11 submodules, ~30 MB total). HTTPS by default; switch to
SSH with `just submodules-ssh` if you have write access.

## 2. Pick a host

The four hosts are:

| Host | Class | When to use |
|------|-------|-------------|
| `desktop` | server, control plane | The always-on tower |
| `cf19` | laptop, BIOS-era | An older laptop (Panasonic CF-MX or similar) |
| `huawei` | laptop, modern Intel | A modern Intel laptop |
| `vm` | isolated test VM | A QEMU/KVM guest for testing |

If you are starting fresh, **`vm` is the safest choice** — it does
not require any specific hardware and uses a minimal baseline.

## 3. Enter the devShell

```bash
nix develop
```

This:

* Pulls all the necessary tools (nix, just, direnv, gh, emacs, …).
* Creates a `.pro-emacs-wrapper/emacs-pro` script that wraps Emacs
  with `-L` flags for every overlay-provided package.
* Exposes `just` recipes that the rest of this page uses.

If you use `direnv`, the `.envrc` will load the same shell
automatically when you `cd` into the directory.

## 4. Build a host

```bash
just build <host>
# e.g. just build vm
```

This runs `nix build ".#nixosConfigurations.<host>.config.system.build.toplevel"`
with the **correct** flake URL (`git+file://$(pwd)?submodules=1`).
The first build takes 10-30 minutes depending on your machine
(downloads ~5 GB of binary cache + builds anything not cached).

## 5. Switch (apply the build)

```bash
sudo just switch <host>
# e.g. sudo just switch vm
```

`just switch` runs `scripts/helper-switch.sh`, which:

* Initializes submodules if they are not already initialized.
* Runs `sudo nixos-rebuild switch` with the correct flake URL.
* On success, fixes ownership of `~/.config/emacs`, `~/.local/state/pro-emacs`,
  `~/.cache/pro-emacs` (because `nixos-rebuild switch` may have
  written them as root).
* Deploys `bin/*` to `~/bin` and adds `~/bin` to `~/.profile`.

## 6. Deploy the AI agent configs

```bash
just deploy-agents
```

This runs `scripts/deploy-agent-configs.sh` (copy-if-missing
deployment of `local-templates/*` to `~/.config/opencode/` and
`~/.pi/agent/`) and `scripts/install-pi-packages.sh` (idempotent
`pi install npm:<pkg>` for every package in `settings.json`).

The `~/.pi/agent/auth.json` file is **never** written by the
deploy — it is created on first run of `pi` and is in the
permission-system deny list.

## 7. Configure secrets

Add your AI provider keys to `~/.authinfo`:

```
machine api.aitunnel.ru  login token  AITUNNEL_KEY_HERE
machine openrouter.ai    login token  OPENROUTER_KEY_HERE
machine api.openai.com   login openai OPENAI_API_KEY_HERE
```

Or, if you prefer GPG encryption, `~/.authinfo.gpg` with the same
format.

The `~/.local/share/pro-nix/load-agent-env.sh` script (deployed by
`pro-agent-configs.nix`) reads the authinfo file and exports
`AITUNNEL_KEY`, `OPENROUTER_KEY`, `OPENAI_API_KEY`, etc. The
`~/.profile` line is added automatically by the activation.

## 8. Set up SSH keys

For SSH access to other hosts in the cluster (or for an external
machine to access this one):

```bash
# Generate a key (one time, on the machine you connect FROM)
ssh-keygen -t ed25519 -C "az@$(hostname)" -f ~/.ssh/id_ed25519

# Copy to the target host
ssh-copy-id -i ~/.ssh/id_ed25519.pub az@desktop.local

# Verify
ssh -o ConnectTimeout=3 desktop 'uname -a'
```

The `~/.ssh/authorized_keys` on each host starts **empty** by
design (`users.users.<name>.openssh.authorizedKeys.keys = []` in
`pro-users.nix`) — keys must be added explicitly, either via
`local.nix` or via `ssh-copy-id`.

## 9. Verify the network layer

```bash
# mDNS resolution
getent hosts desktop.local      # should return a LAN IP

# NFS autofs (on a client host)
systemctl status mnt-desktop.automount
ls /mnt/desktop                  # ≤ 3 s, even if desktop is offline

# SSH candidate list
ssh -G desktop | head -30       # shows the candidates from ssh_config.d/pro.conf
```

## 10. Smoke test

```bash
# NixOS level
nix flake check

# Emacs level
M-x pro/reload-config            # inside Emacs
M-x pro-keys-report-pending      # should print "no pending bindings"

# Network contract
just network-contract

# Headless Emacs tests
just headless-tests
```

If all four pass, you have a working pro-nix install.

## Common pitfalls on first install

| Symptom | Fix |
|---------|-----|
| `nix flake check` complains about missing submodules | `git submodule update --init --recursive` |
| `just switch` fails with `error: path '/nix/store/...emcp' does not exist` | Submodules not initialized. See above. |
| `ssh desktop` hangs | mDNS / Avahi not up. `sudo systemctl restart avahi-daemon` |
| `pi` complains about no `mcp.json` | `just deploy-agents` |
| `pi install` errors with "package not found" | `just install-pi-packages` re-runs with the deployed `settings.json` |
| `M-x pro/reload-config` errors with "module not owned by current user" | `sudo chown -R $USER ~/.config/emacs` (helper-switch.sh does this) |

## What to do after first install

* See [Per-host checklist](workflow/per-host.md) for each host's
  specific steps.
* See [Troubleshooting](workflow/troubleshoot.md) for the symptom →
  cause → fix table.
* Read [Conventions](conventions/_index.md) before making any
  change.
