+++
title = "Flake inputs"
template = "page.html"
weight = 1

[extra]
tldr = "The flake pulls nixos-25.11, home-manager-25.11, opencode-bwrap, pi.nix, and systems. Five overlays. Two host constructors (mkHost full, mkVmHost minimal)."

[[extra.next]]
title = "NixOS modules"
url = "/architecture/modules/"
+++

# Flake inputs

`flake.nix` is the **entry point** of the project. Everything else is a
module, a composition file, or a recipe that the flake glues together.

## Inputs

```nix
inputs = {
  nixpkgs.url       = "nixpkgs/nixos-25.11";
  systems.url       = "github:nix-systems/default";
  home-manager.url  = "github:nix-community/home-manager/release-25.11";
  opencodeBwrap.url = "github:michalrus/opencode-bwrap-nix";
  pi.url            = "github:lukasl-dev/pi.nix";
};
```

* `home-manager.inputs.nixpkgs.follows = "nixpkgs"` — HM shares the same
  nixpkgs pin.
* `opencodeBwrap.inputs.nixpkgs.follows = "nixpkgs"` — same.
* `pi.inputs.nixpkgs.follows = "nixpkgs"`.
* `pi.inputs.systems.follows = "systems"`.

> nix-hermes was removed (it was a fork provided by the user; no longer
> used).

## `nixpkgsConfig`

```nix
nixpkgsConfig = {
  allowUnfree = true;
  rewriteURL = url: ...;  # see below
};
```

The `rewriteURL` function rewrites a few hard-to-reach URLs:

* `https://astron.com/pub/file/` → `https://distfiles.macports.org/file/`
* `https://astron.com/` → `https://distfiles.macports.org/`
* `https://git.kernel.org/` → `https://mirrors.edge.kernel.org/`
* `https://www.kernel.org/` → `https://mirrors.edge.kernel.org/`
* `https://curl.haxx.se/` → `https://curl.se/`

If `NIX_GITHUB_PROXY` is set, GitHub URLs are prefixed with it
(`https://ghproxy.com/`).

## Overlays

`pkgsOverlay = import nixpkgs { overlays = [ ... ]; }` applies five:

```nix
overlays = [
  (import ./nix/overlays/emacs-extra.nix)
  (import ./nix/overlays/opencode-stub.nix)
  (import ./nix/overlays/pi-acp.nix)
  (import ./nix/overlays/mirrors.nix)
  (import ./nix/overlays/github-proxy.nix)
];
```

`emacsPkg = pkgs.emacs30 or pkgs.emacs` — preference for Emacs 30.
`piPkg = pi.packages.x86_64-linux.coding-agent` — the actual `pi` package.

## Special args

```nix
specialArgs = { inherit emacsPkg piPkg opencodeBwrapModule; };
```

These are visible to every module. The `emacsPkg` is consumed by
`emacs/exwm.nix` (so the EXWM session launcher points at the right
binary). `piPkg` is consumed by `configuration.nix` (the upstream
`programs.pi.coding-agent` module). `opencodeBwrapModule` is the
`homeManagerModules.default` of `michalrus/opencode-bwrap-nix`; it is
imported by `modules/pro-users-nixos.nix` to wire the bwrap'd opencode
into Home Manager.

## `globalModules`

```nix
globalModules = [ pi.nixosModules.default ./modules/ssh-agent.nix ];
```

These are added to **every** host evaluation. `pi.nixosModules.default`
brings in the upstream `programs.pi.coding-agent` option set. The local
`modules/ssh-agent.nix` enables the per-user systemd `ssh-agent`
service.

## The two host constructors

```nix
mkHost = extraModules: nixpkgs.lib.nixosSystem {
  inherit system;
  pkgs = pkgsOverlay;
  specialArgs = { inherit emacsPkg piPkg opencodeBwrapModule; };
  modules = [
    home-manager.nixosModules.home-manager
    ./configuration.nix
    ./modules/searxng.nix
  ] ++ globalModules ++ extraModules;
};

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

`mkHost` is the **full** constructor. It imports `configuration.nix` and
`modules/searxng.nix`, plus the per-host modules.

`mkVmHost` is the **minimal** constructor. It does **not** import
`configuration.nix`. This is intentional: the `vm` host is meant for
isolated testing and should not pull in `headscale.nix`, the pro-user
modules, the EXWM glue, etc. As a side effect, `headscale.enable` is
**not even a valid attribute** in the `vm` evaluation — see
`hosts/vm/configuration.nix:35-37` for the comment.

## Hosts

```nix
hosts = {
  cf19    = mkHost [ ./hosts/cf19/configuration.nix    ./hosts/cf19/composition.nix ];
  huawei  = mkHost [ ./hosts/huawei/configuration.nix  ./hosts/huawei/composition.nix ];
  desktop = mkHost [ ./hosts/desktop/configuration.nix ./hosts/desktop/composition.nix ];
  vm      = mkVmHost [ ./hosts/vm/configuration.nix    ./hosts/vm/composition.nix ];
};
```

Each `mkHost` call passes the host's `configuration.nix` (kernel,
hostname, hardware) and `composition.nix` (which
`system-package-sets-*` to add).

## Outputs

```nix
nixosConfigurations = hosts;          # the four hosts above

checks.${system} = { default = hosts.huawei.config.system.build.toplevel; ... };

apps.${system} = {
  check-all   = ...;    # builds the three full hosts in sequence
  site-serve  = ...;    # zola serve, see flake.nix
  site-regen  = ...;    # regenerate auto-gen pages
};

devShells.${system}.default = ...;   # emacs with 25+ packages on EMACSLOADPATH

packages.${system}.site = ...;       # the static site (this site)

treesitterGrammars = import ./nix/treesitter-grammars.nix { inherit pkgs; };
```

## Checks (slow, gated)

```nix
checks.${system} = (
  { default = hosts.huawei.config.system.build.toplevel; }
  // (if runSlow then {
    huawei-boot               = import ./tests/vm/huawei-boot.nix { ... };
    basic-activation-test     = import ./tests/vm/test-basic-activation.nix { ... };
    cf19-switch-dbus-regression = import ./tests/vm/cf19-switch-dbus-regression.nix { ... };
  } else {})
);
```

`runSlow = builtins.getEnv "PRO_NIX_RUN_SLOW_CHECKS" == "1"`. By
default only the fast toplevel check runs. Set the env var to run the
three VM tests too.

## The devShell `emacs-pro` wrapper

On `nix develop`, the flake writes a script at
`$PWD/.pro-emacs-wrapper/emacs-pro` (in the current working directory):

```sh
#!/bin/sh
EMACS_BIN="${emacsPkg}/bin/emacs"
exec "$EMACS_BIN" -Q -L <pkg1>/share/emacs/site-lisp \
                  -L <pkg2>/share/emacs/site-lisp \
                  ... \
                  "$@"
```

The `-L` flags cover every overlay-provided Emacs package (visually,
`acp`, `agent-shell`, `agent-shell-hud`, `atlas`, `carriage`, `emcp`,
`http-server`, `pro-tabs`, `shaoline`, `telega`, `telega-server`). The
script is also added to `$PATH` for the session.
