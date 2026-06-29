+++
title = "vm"
template = "page.html"
weight = 4

[extra]
tldr = "Isolated test VM, mkVmHost (no configuration.nix), no GUI, no headscale option, NOPASSWD sudo, empty root password, NFS client for testing."

[[extra.next]]
title = "All hosts"
url = "/hosts/"

[[extra.next]]
title = "Quick start"
url = "/workflow/quickstart/"
+++

# vm

`vm` is the **isolated test VM** in the cluster. It is built by
`mkVmHost` in `flake.nix:92-102` — a **separate** host constructor
that does not import `configuration.nix`. The reason for the
separation: `vm` is meant for testing, and should not pull in the
full network stack (headscale, pro-peer, EXWM glue) that a real
host needs.

* **Class.** Single-purpose test VM, no GUI.
* **Boot.** systemd-boot (EFI), no NVRAM writes.
* **Roles.** `vm, lab`.

## The `mkVmHost` constructor

```nix
mkVmHost = extraModules: nixpkgs.lib.nixosSystem {
  inherit system;
  pkgs = pkgsOverlay;
  specialArgs = { inherit emacsPkg piPkg opencodeBwrapModule; };
  modules = [
    home-manager.nixosModules.home-manager
    ./modules/packages-runtime.nix
    ./modules/tty-console.nix
    ./modules/searxng.nix
  ] ++ extraModules;
};
```

The minimal baseline: `packages-runtime + tty-console + searxng` plus
the per-host `configuration.nix` and `composition.nix`. **No**
`configuration.nix`, **no** `headscale.nix`, **no** `pro-network.nix`,
**no** `pro-users.nix` (instead, `pro-users` IS imported from
`hosts/vm/configuration.nix:6` because that file picks its own users
module — see below).

## The implication: `headscale.*` is undefined

In the `vm` evaluation, `headscale.enable` is **not** a valid
attribute. Trying to set it (e.g. `headscale.enable = false` in
`hosts/vm/configuration.nix`) would fail the evaluation.

`hosts/vm/configuration.nix:35-37` has a comment to that effect:

```nix
# VM собирается через `mkVmHost` в flake.nix, который НЕ импортирует
# общий `configuration.nix` (а значит и `headscale.nix`). Здесь нельзя
# ссылаться на `headscale.*` — опция не существует в этом evaluation.
```

## The host config

```nix
{ config, lib, pkgs, ... }:
{
  imports = [
    ../../modules/pro-users.nix
    ../../modules/pro-docker.nix
    ../../modules/pro-nfs.nix
    ../../modules/pro-spellcheck.nix
  ];

  networking.hostName = "vm";

  fileSystems."/" = {
    device = "/dev/sda1";
    fsType = "ext4";
  };

  boot.loader.grub.enable = lib.mkForce false;
  boot.loader.systemd-boot.enable = lib.mkForce true;
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

  services.xserver.enable = lib.mkForce false;
  services.displayManager.enable = lib.mkForce false;
  security.sudo.enable = true;
  security.sudo.wheelNeedsPassword = lib.mkForce false;

  users.users.root.password = "";

  pro.nfs.client.enable = true;
}
```

The imports are **purposeful**: `pro-users.nix` (for the same 4-user
setup as the other hosts), `pro-docker.nix` (for the dev
microservice stack), `pro-nfs.nix` (for `pro.nfs.client`),
`pro-spellcheck.nix` (for the vendored ru_RU hunspell). No GUI
modules, no EXWM glue, no peer / ssh-agent / network modules.

`users.users.root.password = ""` is intentional — this is an
isolated VM with no network exposure. The empty password means
`root` cannot log in via password (it can only log in via the
console or via `sudo` from a user).

`security.sudo.wheelNeedsPassword = lib.mkForce false` — sudo is
passwordless for wheel users. Same logic as `root`: this is an
isolated test environment.

## The composition

```nix
{ pkgs, ... }:
let
  runtime = import ../../modules/system-package-sets-runtime.nix { inherit pkgs; };
  dev     = import ../../modules/system-package-sets-dev.nix { inherit pkgs; };
  exwm    = import ../../modules/system-package-sets-exwm.nix { inherit pkgs; };
  privacy = import ../../modules/system-package-sets-privacy.nix { inherit pkgs; };
  tor     = import ../../modules/system-package-sets-tor.nix { inherit pkgs; };
in
{
  environment.systemPackages = with pkgs;
    runtime.runtimePackages
    ++ dev.devPackages
    ++ exwm.exwmPackages
    ++ privacy.privacyPackages
    ++ tor.torControlPackages
    ++ [ gh tor-browser ];
}
```

A middle ground: `runtime + dev + exwm + privacy + tor + gh +
tor-browser`. Not as heavy as `huawei` (no `desktopHeavy`, no `lsp`,
no `media`), but not as minimal as `cf19`.

## What is on this host

* `pro-dev` Docker bridge (172.20.0.0/16) from `pro-docker.nix`.
* `gh` (GitHub CLI) and `tor-browser` (direct package, not in a
  composition file).
* NFS client (`pro.nfs.client.enable = true`) so the VM can mount
  `desktop.local:/srv/nfs` for testing the autofs flow.
* The vendored Russian hunspell from `pro-spellcheck.nix`.
* Everything in `runtime` (openssh, python3, jq, ripgrep, fd, …).
* Everything in `dev` (direnv, shellcheck, bat, fzf, nodejs_20, …).
* Everything in `exwm` (xset, wmname, xdotool, …) — not used here,
  but installed for parity with the other hosts.
* Everything in `privacy` (tor, torsocks, snowflake, dnscrypt-proxy,
  mullvad-vpn, …) — same reason.
* Everything in `tor` (pro-tor CLI, torwrap, torsocks, proxychains).

## What is **not** on this host

* No `headscale`. The option does not exist in this evaluation.
* No `pro-peer`. There is no need for peer discovery in an
  isolated VM.
* No GUI (X server, display manager, EXWM, Sway, i3, Cinnamon).
* No `pro.emacs.gui.enable`. `pro-emacs.el` is still on the
  closure, but the session never starts it.
* No NFS server (only client).

## The VM image

The VM is built as a NixOS qcow2 image through `nixos-generators`
(in a separate workflow, not in the flake). The image boots
under QEMU/KVM with 2 GB RAM and 1 vCPU. The `mkVmHost` constructor
is **also** used for `nixosTests` test cases — the same
configuration serves both purposes.

## Post-switch checklist

```bash
# 1. SSH keys
ssh-copy-id -i ~/.ssh/id_ed25519.pub az@vm.local

# 2. systemctl --failed (no surprise from the minimal baseline)
systemctl --failed

# 3. NFS autofs (the one network dependency)
systemctl status mnt-desktop.automount
ls /mnt/desktop                # ≤ 3 s, even if desktop is offline

# 4. Docker (pro-dev bridge)
docker network ls              # should show 'pro-dev'
docker run --rm --network pro-dev alpine:3.20 ip addr

# 5. nix flake check
nix flake check
```

## When to use `vm`

* Testing a new `pro-*.nix` module before applying it to a real host.
* Reproducing a bug from `cf19` or `huawei` in a clean environment.
* Validating that a `nix flake update` does not break the build
  before propagating to the cluster.
* The `huawei-boot.nix` and `cf19-switch-dbus-regression.nix` tests
  use the `mkVmHost` infrastructure internally.
