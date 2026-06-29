+++
title = "NixOS modules"
template = "page.html"
weight = 2

[extra]
tldr = "50+ files in modules/ across 5 patterns: pro-*, session-*, system-*, system-package-sets-* (NOT modules), nix-*."

[[extra.next]]
title = "Composition files"
url = "/architecture/composition/"

[[extra.next]]
title = "Reference options"
url = "/reference/options/"
+++

# NixOS modules

`modules/` is wider than its name suggests. There are **five** patterns
of files, each with a different role.

## The five patterns

| Pattern | Role | How to remove |
|---------|------|---------------|
| `modules/pro-*.nix` | Regular NixOS modules | Remove from `imports` in `configuration.nix` or `hosts/*/configuration.nix` |
| `modules/session-*.nix` | Window managers / display managers | Same |
| `modules/system-*.nix` | Low-level policies (boot, systemd) | Standard `imports` removal |
| `modules/system-package-sets-*.nix` | **NOT NixOS modules** — functions `{ pkgs }: { somePackages = [...]; }` imported from `hosts/*/composition.nix` | Remove the file + the `import` + the `++ X.somePackages` in **both** `hosts/*/composition.nix` |
| `modules/nix-*.nix` | Custom packages / units (overlays, derivations) | Standard `imports` removal (or remove from the `overlays = [...]` list in `flake.nix` if it's an overlay) |

## Index of the 50+ modules

### Network (the headline layer)

* `pro-hosts.nix` — the host registry. `pro.hosts.<name> = { sshUser, roles, tailnet, onion, addr, tags }`.
* `pro-network.nix` — Avahi + nss-mdns, mDNS port, LAN-gateway IP forwarding.
* `pro-ssh-clients.nix` — generates `/etc/ssh/ssh_config.d/pro.conf` with one `Host` block per registered host.
* `headscale.nix` — control plane for the WireGuard mesh. The `headscale` option set.
* `pro-peer.nix` — Avahi publish, SSH hardening, optional GPG key sync, optional Tor hidden service, optional Yggdrasil / WireGuard.
* `host-policies.nix` — host-conditional policies (Tor defaults on all, snowflake on huawei, iwlwifi power-save on cf19).
* `pro-nfs.nix` — NFSv4 server/client. Mutually exclusive on the same host.
* `pro-storage.nix` — Samba (with `pro-samba-setup-users` oneshot) + Syncthing + private/public shares.
* `pro-smb-automount.nix`, `pro-samba-keys-sync.nix`, `pro-user-automount.nix` — system/user automount templates + decrypt-on-demand.
* `pro-privacy.nix` — Tor + obfs4 + meek + snowflake ClientTransportPlugin, i2p, dnscrypt-proxy, mullvad, nyx, onionshare, proxychains.
* `searxng.nix` — self-hosted metasearch (currently `lib.mkForce false` at the top level due to a settings.yml bug).

### Users &amp; permissions

* `pro-users.nix` — 4 Unix users (`az, za, la, bo`), groups (`networkmanager`, `wheel`, `bluetooth`, `docker`, `input`, `uinput`, `pro`, `pro-agent`), NOPASSWD sudo, umask 0002.
* `pro-users-nixos.nix` — Home Manager for pro users. Long list of provided Emacs packages, bridge to `pro.emacs.*`.
* `pro-users-termux.nix` — Home Manager for Termux (Android), no GUI.
* `pro-home-perms.nix` — per-user activation that chowns protected dirs.
* `ssh-agent.nix` — per-user systemd `ssh-agent` with `%t/ssh-agent.socket`, env script in `/etc/profile.d/ssh-agent.sh`.

### System and hardware

* `system-boot.nix` — GRUB default `nodev`, EFI touch defaults, plymouth spinner, `linuxPackages_6_6`, sysrq=1.
* `tty-console.nix` — `console.useXkbConfig = true`, `LatArCyrHeb-16.psfu.gz`, `SYSTEMD_VCONSOLE_FORCE=1`, gpm, kbdrate.
* `nix-cuda-compat.nix` — overlay: `types.atom` in formats, `cudaPackages.{cudaFlags, cudaVersion}`.
* `zram-slice.nix` — `systemd.services.enable-zram` oneshot. `size = "auto"` = 50% RAM, cap 16384 MB.
* `packages-runtime.nix` — minimal runtime: bashInteractive, openssh, python3, dbus, gawk, kbd, mc, emacs, rxvt-unicode, curl/wget, jq, just, git, gh, ripgrep, fd, tmux, tree, htop, lsof, alsa-utils, beep.
* `fbterm-tty.nix` — fbterm on tty2. Off by default; hosts opt in.
* `pro-power-beep.nix` — two-level low-battery beep. PC speaker → BEL → ALSA. C5-E5-G5 warning, A5-A5-A5-C6 urgent.
* `pro-wifi-watchdog.nix` — periodic `nmcli connection up` if the target IP is unreachable. Disabled when NetworkManager is off.
* `pro-emacs-rescue.nix` — `Control+Alt+Shift+r` → xbindkeys grab → emacsclient probe → poke stuck `*package*` → `kill -USR2` → `systemd-run --user --scope` restart.
* `zram-slice.nix` — see above.

### Session / display

* `session-base.nix` — LightDM, xkb `us,ru ctrl:nocaps,grp:toggle,grp_led:caps`.
* `session-i3.nix` — i3 + polybar (uses `conf/i3-config.in`).
* `session-sway.nix` — Sway + waybar/mako/swaybg/swaylock/swayidle/wl-clipboard/wofi/foot/grim/slurp (uses `conf/sway-config.in`).
* `session-cinnamon.nix` — Cinnamon (heavy).
* `session-fonts.nix` — font packages + `conf/fonts.conf`, `conf/gtk-*/settings.ini`, `conf/qt*ct.conf`, `conf/kdeglobals`, `conf/Xresources`, `conf/dunstrc`.
* `session-audio.nix` — PipeWire (pulse + alsa + wireplumber), rtkit, ALSA persistence.
* `pro-desktop.nix` — wrapper: session-base + session-fonts + session-audio + session-cinnamon + firefox.
* `pro-exwm-desktop.nix` — EXWM GUI layer (feh, scrot, dunst, flameshot, mpv, …).
* `pro-heavy-desktop.nix` — heavy: chromium, telegram-desktop, element-desktop, jami, weechat, ffmpegthumbnailer.
* `profile-exwm-minimal.nix` — `pro.profiles.exwmMinimal.enable` → EXWM windowManager + gdm=false + cinnamon=false + per-host sessionCommands.
* `pro-profiles.nix` — declares `pro.profiles` as a submodule with empty options so other modules can add nested options.

### Dev / build / Docker

* `pro-dev.nix` — dev toolchain (direnv, shellcheck, shfmt, bat, tldr, pipx, nodejs_20, esbuild, prettier, typescript-language-server, rust-analyzer, bash-language-server, cmake, gcc, clang, ag, pt, fzf, lnav, mosh, pandoc, graphviz, plantuml, mermaid-cli, eldev, cask, lazydocker, dive, ctop, trivy, hadolint, sops, age).
* `pro-haskell.nix` — ghc, haskell-language-server, cabal-install, stack, ghcid, hlint, fourmolu.
* `pro-docker.nix` — `virtualisation.docker.enable = true` + oneshot `docker-network-pro-dev` creates bridge `pro-dev` (172.20.0.0/16 gw .1).
* `pro-spellcheck.nix` — vendored ru_RU hunspell from LibreOffice/dictionaries (MPL-2.0), wrapped via `makeWrapper` with `DICPATH` baked in.
* `opencode-tui.nix` — `pro.opencode.tui.enable` → writes `~/.config/opencode/tui.json`.
* `pro-agent-configs.nix` — `home.activation.pro-agent-configs-deploy` deploys `local-templates/{pi,opencode}/*` to `$HOME` with `copy_if_missing` semantics; idempotent `~/.profile` marker.

### Composition files (functions, not modules)

These are **not** NixOS modules. They are `{ pkgs }: { somePackages = [ … ]; }` functions imported from `hosts/*/composition.nix`.

* `system-package-sets-runtime.nix` — `runtimePackages`.
* `system-package-sets-dev.nix` — `devPackages` + `llmLabCmd` + `pythonCmd`.
* `system-package-sets-exwm.nix` — `exwmPackages`.
* `system-package-sets-desktop-heavy.nix` — `desktopHeavyPackages` (chromium, firefox, telegram, element, jami, steam, dunst, flameshot, copyq, pavucontrol, ffmpeg-full, deluge) plus `chromium` and `firefox` wrappers with `systemd-run --user --scope -p MemoryMax=... -p CPUQuota=...`.
* `system-package-sets-lsp.nix` — `lspPackages` (pyright, jdtls, rust-analyzer, gopls, bash-language-server) with `maybe = pkg: if pkg == null then [] else [pkg]` guards.
* `system-package-sets-media.nix` — `mediaPackages` (ffmpeg-full, mpv, ffmpegthumbnailer).
* `system-package-sets-privacy.nix` — `privacyPackages` (tor, torsocks, obfs4, snowflake, nyx, onionshare, dnscrypt-proxy, wireguard-tools, yggdrasil, i2p, proxychains, mullvad-vpn, tor-browser).
* `system-package-sets-tor.nix` — `torControlPackages` (lightweight CLI: `pro-tor`, `torwrap`).
* `system-package-sets-lsp.nix` — see above.

## How a host picks composition files

`hosts/cf19/composition.nix` (minimal):

```nix
{ lib, pkgs, ... }:
let
  tor = import ../../modules/system-package-sets-tor.nix { inherit pkgs; };
in
{
  pro.profiles.exwmMinimal.enable = lib.mkDefault true;
  environment.systemPackages = tor.torControlPackages;
}
```

`hosts/huawei/composition.nix` (heaviest):

```nix
environment.systemPackages = with pkgs;
  runtime.runtimePackages
  ++ dev.devPackages
  ++ exwm.exwmPackages
  ++ lsp.lspPackages
  ++ privacy.privacyPackages
  ++ media.mediaPackages
  ++ tor.torControlPackages
  ++ (import ../../modules/system-package-sets-desktop-heavy.nix { inherit pkgs; }).desktopHeavyPackages
  ++ [ tor-browser ];
```

`hosts/vm/composition.nix`:

```nix
environment.systemPackages = with pkgs;
  runtime.runtimePackages
  ++ dev.devPackages
  ++ exwm.exwmPackages
  ++ privacy.privacyPackages
  ++ tor.torControlPackages
  ++ [ gh tor-browser ];
```

`hosts/desktop/composition.nix` (medium):

```nix
environment.systemPackages = tor.torControlPackages ++ (with pkgs; [ ... ]);
```

The shape is: pick the composition files that match the host's role,
`++` them, and add any host-specific package at the end.

## Detection in tooling

`tools/surface-lint.sh` (with `--check-style`) requires every
`modules/*.nix` to have a five-section header
(Назначение / Цель / Контракт / Побочные эффекты / Proof). It also
checks for Cyrillic text — the project convention is to write the
header in Russian.

`tools/holo-verify.sh unit` runs the 10 unit tests under
`tests/contract/unit/`.
