+++
title = "Composition files"
template = "page.html"
weight = 3

[extra]
tldr = "system-package-sets-* are functions, not modules. Hosts import them, `++` them into environment.systemPackages. A clean way to share package lists between hosts."

[[extra.next]]
title = "Emacs bootstrap"
url = "/architecture/emacs-base/"

[[extra.next]]
title = "Hosts"
url = "/hosts/"
+++

# Composition files

A **composition file** is `modules/system-package-sets-*.nix`. It is
**not** a NixOS module — it does not declare options, does not appear
in `imports`, and does not get evaluated as part of a module
configuration. It is a plain function:

```nix
{ pkgs }:
{
  somePackages = with pkgs; [
    package-a
    package-b
    ...
  ];
}
```

The host's `composition.nix` imports one or more of these, calls them
with the right `pkgs`, and `++`s the resulting `somePackages` list
into `environment.systemPackages`.

## Why this pattern

Three reasons:

1. **No merge semantics.** `environment.systemPackages` is a list, and
   list concatenation is well-defined. There is no `mkDefault` / `mkForce`
   interaction — every `++` just appends. Duplicates are deduped at
   build time.
2. **Reuse across hosts.** The same `runtime` set is on `cf19`,
   `huawei`, and `vm`. The same `desktopHeavy` set is on `huawei` and
   `desktop` (in the future). Without the function indirection, you
   would copy-paste the package list.
3. **No accidental coupling.** Because it is not a module, it cannot
   declare `options`, cannot read `config`, cannot have side effects.
   It is a pure function of `pkgs` → `attrsOf (listOf package)`.

## The nine composition files

| File | Returns | What it contains |
|------|---------|------------------|
| `system-package-sets-runtime.nix` | `runtimePackages` | The base runtime (bashInteractive, openssh, python3, dbus, gawk, kbd, mc, emacs, rxvt-unicode, curl, wget, jq, just, git, gh, ripgrep, fd, tmux, tree, htop, lsof, alsa-utils, beep, …) |
| `system-package-sets-dev.nix` | `devPackages`, `llmLabCmd`, `pythonCmd` | Dev toolchain (direnv, shellcheck, shfmt, bat, tldr, pipx, nodejs_20, …), the `llm-lab` Python wrapper with jupyter/transformers/datasets, … |
| `system-package-sets-exwm.nix` | `exwmPackages` | X11 / EXWM UI helpers (xset, xhost, setxkbmap, wmname, xbindkeys, xdotool, xclip, xauth, feh, xterm, scrot, dunst, flameshot, …) |
| `system-package-sets-desktop-heavy.nix` | `desktopHeavyPackages` | Chromium (with `systemd-run --user --scope -p MemoryMax=4500M -p CPUQuota=90%`), Firefox (2.5G / 90%), telegram-desktop, element-desktop, jami, ffmpeg-full, steam, steam-run, … |
| `system-package-sets-lsp.nix` | `lspPackages` | pyright, jdtls, rust-analyzer, gopls, bash-language-server (all `maybe`'d so a missing upstream returns `[]`) |
| `system-package-sets-media.nix` | `mediaPackages` | ffmpeg-full, mpv, ffmpegthumbnailer |
| `system-package-sets-privacy.nix` | `privacyPackages` | tor, torsocks, obfs4, snowflake, nyx, onionshare, dnscrypt-proxy, wireguard-tools, yggdrasil, i2p, proxychains, mullvad-vpn, tor-browser |
| `system-package-sets-tor.nix` | `torControlPackages` | `pro-tor` (writeShellApplication), `torwrap` (writeShellApplication), torsocks, proxychains |
| `system-package-sets-lsp.nix` | `lspPackages` | (see above) |

## Reading a composition file

Example — `system-package-sets-tor.nix`:

```nix
{ pkgs }:
let
  proTor = pkgs.writeShellApplication {
    name = "pro-tor";
    runtimeInputs = [ pkgs.bash pkgs.iproute2 pkgs.curl pkgs.gnused ];
    text = builtins.readFile ../../scripts/pro-tor;
  };
  torwrap = pkgs.writeShellApplication {
    name = "torwrap";
    runtimeInputs = [ pkgs.bash ];
    text = builtins.readFile ../../bin/torwrap;
  };
in
{
  torControlPackages = [
    proTor
    torwrap
    pkgs.torsocks
    pkgs.proxychains
  ];
}
```

`writeShellApplication` is `nixpkgs`'s "build a shell script with
correct shebang and runtime deps" helper. Reading the script body from
`../../scripts/pro-tor` keeps the source of truth in one place.

## How a host uses a composition file

`hosts/cf19/composition.nix`:

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

`hosts/huawei/composition.nix`:

```nix
{ pkgs, ... }:
let
  desktopHeavy = import ../../modules/system-package-sets-desktop-heavy.nix { inherit pkgs; };
  privacy      = import ../../modules/system-package-sets-privacy.nix { inherit pkgs; };
  lsp          = import ../../modules/system-package-sets-lsp.nix { inherit pkgs; };
  media        = import ../../modules/system-package-sets-media.nix { inherit pkgs; };
  runtime      = import ../../modules/system-package-sets-runtime.nix { inherit pkgs; };
  dev          = import ../../modules/system-package-sets-dev.nix { inherit pkgs; };
  exwm         = import ../../modules/system-package-sets-exwm.nix { inherit pkgs; };
  tor          = import ../../modules/system-package-sets-tor.nix { inherit pkgs; };
in
{
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
}
```

A pattern: `let` block imports each composition file with `inherit pkgs`,
then `environment.systemPackages` is a `++`-concatenated list of the
relevant `.fooPackages` attrs.

## Adding a new composition file

1. Create `modules/system-package-sets-<name>.nix` with the function
   pattern.
2. Decide which hosts need it.
3. Add the `import ../../modules/system-package-sets-<name>.nix { inherit pkgs; }` and the `++ X.<attr>` to each host's `composition.nix`.
4. Optionally add it to `tools/surface-lint.sh` and `tools/holo-verify.sh`
   so the contract is enforced.

## Removing a composition file

A composition file that nothing imports is dead code. Detect:

```bash
rg -l "system-package-sets-<name>" hosts/    # should be empty
```

If empty, delete the file. There is no `imports` list to clean up,
because the file is **never** in `imports`.

> **The `pro-*.nix` and `system-package-sets-*.nix` distinction is a
> > known landmine.** New contributors sometimes put a `system-package-sets-*`
> > file into `imports` — the file then evaluates as a NixOS module
> > (a string), which fails with "expected a module attribute set". The
> > fix is to import it from `composition.nix`, not from
> > `configuration.nix`.
