+++
title = "Flake inputs"
template = "page.html"
weight = 1

[extra]
tldr = "Flake подтягивает nixos-25.11, home-manager-25.11, opencode-bwrap, pi.nix, systems. 5 overlays. Два host-конструктора (mkHost полный, mkVmHost минимальный)."

[[extra.next]]
title = "NixOS-модули"
url = "/architecture/modules/"
+++

# Flake inputs

`flake.nix` — **входная точка** проекта. Всё остальное — модуль,
composition-файл или рецепт, который flake склеивает.

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

* `home-manager.inputs.nixpkgs.follows = "nixpkgs"` — HM делит тот
  же nixpkgs-pin.
* `opencodeBwrap.inputs.nixpkgs.follows = "nixpkgs"` — то же.
* `pi.inputs.nixpkgs.follows = "nixpkgs"`.
* `pi.inputs.systems.follows = "systems"`.

> nix-hermes был удалён (это был форк от пользователя; больше не
> используется).

## `nixpkgsConfig`

```nix
nixpkgsConfig = {
  allowUnfree = true;
  rewriteURL = url: ...;  # см. ниже
};
```

Функция `rewriteURL` переписывает несколько трудно-достижимых URL:

* `https://astron.com/pub/file/` → `https://distfiles.macports.org/file/`
* `https://astron.com/` → `https://distfiles.macports.org/`
* `https://git.kernel.org/` → `https://mirrors.edge.kernel.org/`
* `https://www.kernel.org/` → `https://mirrors.edge.kernel.org/`
* `https://curl.haxx.se/` → `https://curl.se/`

Если `NIX_GITHUB_PROXY` задан, GitHub-URL получают его как префикс
(`https://ghproxy.com/`).

## Overlays

`pkgsOverlay = import nixpkgs { overlays = [ ... ]; }` применяет
пять:

```nix
overlays = [
  (import ./nix/overlays/emacs-extra.nix)
  (import ./nix/overlays/opencode-stub.nix)
  (import ./nix/overlays/pi-acp.nix)
  (import ./nix/overlays/mirrors.nix)
  (import ./nix/overlays/github-proxy.nix)
];
```

`emacsPkg = pkgs.emacs30 or pkgs.emacs` — предпочтение Emacs 30.
`piPkg = pi.packages.x86_64-linux.coding-agent` — собственно
пакет `pi`.

## Special args

```nix
specialArgs = { inherit emacsPkg piPkg opencodeBwrapModule; };
```

Видны каждому модулю. `emacsPkg` потребляется `emacs/exwm.nix`
(EXWM-session-launcher указывает на правильный бинарь). `piPkg` —
`configuration.nix` (upstream-модуль `programs.pi.coding-agent`).
`opencodeBwrapModule` — это `homeManagerModules.default` из
`michalrus/opencode-bwrap-nix`; импортируется в
`modules/pro-users-nixos.nix`, чтобы завести bwrap'нутый opencode
в Home Manager.

## `globalModules`

```nix
globalModules = [ pi.nixosModules.default ./modules/ssh-agent.nix ];
```

Добавляются к **каждой** host-эвалюации. `pi.nixosModules.default`
приносит опции upstream-`programs.pi.coding-agent`. Локальный
`modules/ssh-agent.nix` включает per-user systemd `ssh-agent`-сервис.

## Два host-конструктора

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

`mkHost` — **полный** конструктор. Импортирует `configuration.nix`
и `modules/searxng.nix`, плюс per-host модули.

`mkVmHost` — **минимальный** конструктор. **Не** импортирует
`configuration.nix`. Это сознательно: `vm`-хост предназначен для
изолированного тестирования и не должен тянуть полный сетевой стек
(headscale, pro-peer, EXWM-glue). Побочный эффект — `headscale.enable`
**даже не валидный атрибут** в eval `vm` — см.
`hosts/vm/configuration.nix:35-37`.

## Хосты

```nix
hosts = {
  cf19    = mkHost [ ./hosts/cf19/configuration.nix    ./hosts/cf19/composition.nix ];
  huawei  = mkHost [ ./hosts/huawei/configuration.nix  ./hosts/huawei/composition.nix ];
  desktop = mkHost [ ./hosts/desktop/configuration.nix ./hosts/desktop/composition.nix ];
  vm      = mkVmHost [ ./hosts/vm/configuration.nix    ./hosts/vm/composition.nix ];
};
```

Каждый вызов `mkHost` передаёт host-овский `configuration.nix`
(kernel, hostname, железо) и `composition.nix` (какие
`system-package-sets-*` добавить).

## Outputs

```nix
nixosConfigurations = hosts;          # четыре хоста выше

checks.${system} = { default = hosts.huawei.config.system.build.toplevel; ... };

apps.${system} = {
  check-all   = ...;    # собирает три полных хоста последовательно
  site-serve  = ...;    # zola serve, см. flake.nix
  site-regen  = ...;    # регенерация auto-gen страниц
};

devShells.${system}.default = ...;   # emacs с 25+ пакетами на EMACSLOADPATH

packages.${system}.site = ...;       # статический сайт (этот сайт)

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

`runSlow = builtins.getEnv "PRO_NIX_RUN_SLOW_CHECKS" == "1"`. По
умолчанию запускается только быстрый toplevel-чек. Поставьте env
var, чтобы запустить три VM-теста.

## Обёртка `emacs-pro` из devShell

На `nix develop` flake пишет скрипт в
`$PWD/.pro-emacs-wrapper/emacs-pro` (в текущей рабочей
директории):

```sh
#!/bin/sh
EMACS_BIN="${emacsPkg}/bin/emacs"
exec "$EMACS_BIN" -Q -L <pkg1>/share/emacs/site-lisp \
                  -L <pkg2>/share/emacs/site-lisp \
                  ... \
                  "$@"
```

`-L` флаги покрывают каждый overlay-предоставленный Emacs-пакет
(`acp`, `agent-shell`, `agent-shell-hud`, `atlas`, `carriage`,
`emcp`, `http-server`, `pro-tabs`, `shaoline`, `telega`,
`telega-server`). Скрипт также добавляется в `$PATH` на сессию.
