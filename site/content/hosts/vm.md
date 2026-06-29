+++
title = "vm"
template = "page.html"
weight = 4

[extra]
tldr = "Изолированная тестовая VM, mkVmHost (без configuration.nix), без GUI, нет headscale-опции, NOPASSWD sudo, пустой root-пароль, NFS-клиент для тестов."

[[extra.next]]
title = "Все хосты"
url = "/hosts/"

[[extra.next]]
title = "Быстрый старт"
url = "/workflow/quickstart/"
+++

# vm

`vm` — **изолированная тестовая VM** в кластере. Собирается через
`mkVmHost` в `flake.nix:92-102` — **отдельный** host-конструктор,
который не импортирует `configuration.nix`. Причина разделения: `vm`
предназначен для тестирования и не должен тянуть полный сетевой
стек (headscale, pro-peer, EXWM-glue), который нужен реальному
хосту.

* **Класс.** Single-purpose test VM, без GUI.
* **Загрузка.** systemd-boot (EFI), без NVRAM-записей.
* **Роли.** `vm, lab`.

## Конструктор `mkVmHost`

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

Минимальный baseline: `packages-runtime + tty-console + searxng`
плюс per-host `configuration.nix` и `composition.nix`. **Нет**
`configuration.nix`, **нет** `headscale.nix`, **нет**
`pro-network.nix`, **нет** `pro-users.nix` (вместо этого
`pro-users` импортируется из `hosts/vm/configuration.nix:6`,
потому что этот файл выбирает свой users-модуль — см. ниже).

## Следствие: `headscale.*` не определена

В eval `vm` `headscale.enable` — **не** валидный атрибут.
Попытка установить его (например, `headscale.enable = false` в
`hosts/vm/configuration.nix`) провалит eval.

`hosts/vm/configuration.nix:35-37` имеет комментарий об этом:

```nix
# VM собирается через `mkVmHost` в flake.nix, который НЕ импортирует
# общий `configuration.nix` (а значит и `headscale.nix`). Здесь нельзя
# ссылаться на `headscale.*` — опция не существует в этом evaluation.
```

## Host-конфиг

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

Импорты **целевые**: `pro-users.nix` (тот же 4-user setup что и на
других хостах), `pro-docker.nix` (для dev-microservice-stack),
`pro-nfs.nix` (для `pro.nfs.client`), `pro-spellcheck.nix` (для
vendored ru_RU hunspell). Без GUI-модулей, без EXWM-glue, без peer
/ ssh-agent / сетевых модулей.

`users.users.root.password = ""` сознательно — это изолированная VM
без сетевой экспозиции. Пустой пароль значит, что `root` не может
логиниться по паролю (только через консоль или через `sudo` от
юзера).

`security.sudo.wheelNeedsPassword = lib.mkForce false` — sudo без
пароля для wheel-юзеров. Та же логика, что и для `root`: это
изолированная test-среда.

## Composition

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

Средний вариант: `runtime + dev + exwm + privacy + tor + gh +
tor-browser`. Не такой тяжёлый, как `huawei` (без `desktopHeavy`,
без `lsp`, без `media`), но не такой минимальный, как `cf19`.

## Что на этом хосте

* Docker-мост `pro-dev` (172.20.0.0/16) из `pro-docker.nix`.
* `gh` (GitHub CLI) и `tor-browser` (прямой пакет, не в
  composition-файле).
* NFS-клиент (`pro.nfs.client.enable = true`), так что VM может
  монитировать `desktop.local:/srv/nfs` для тестирования autofs.
* Vendored Russian hunspell из `pro-spellcheck.nix`.
* Всё из `runtime` (openssh, python3, jq, ripgrep, fd, …).
* Всё из `dev` (direnv, shellcheck, bat, fzf, nodejs_20, …).
* Всё из `exwm` (xset, wmname, xdotool, …) — здесь не
  используется, но установлено для паритета с другими хостами.
* Всё из `privacy` (tor, torsocks, snowflake, dnscrypt-proxy,
  mullvad-vpn, …) — по той же причине.
* Всё из `tor` (pro-tor CLI, torwrap, torsocks, proxychains).

## Чего на этом хосте **нет**

* Нет `headscale`. Опция не существует в этом eval.
* Нет `pro-peer`. Нет нужды в peer-discovery в изолированной VM.
* Нет GUI (X-сервер, display manager, EXWM, Sway, i3, Cinnamon).
* Нет `pro.emacs.gui.enable`. `pro-emacs.el` всё ещё в closure,
  но сессия никогда не стартует его.
* Нет NFS-сервера (только клиент).

## Образ VM

VM собирается как NixOS qcow2-образ через `nixos-generators`
(в отдельном workflow, не в flake). Образ загружается под
QEMU/KVM с 2 GB RAM и 1 vCPU. Конструктор `mkVmHost` также
используется для `nixosTests` — та же конфигурация служит обеим
целям.

## Post-switch чек-лист

```bash
# 1. SSH-ключи
ssh-copy-id -i ~/.ssh/id_ed25519.pub <user>@vm.local

# 2. systemctl --failed (без сюрпризов от минимального baseline)
systemctl --failed

# 3. NFS autofs (единственная сетевая зависимость)
systemctl status mnt-desktop.automount
ls /mnt/desktop                # ≤ 3 с, даже если desktop выключен

# 4. Docker (мост pro-dev)
docker network ls              # должно показать 'pro-dev'
docker run --rm --network pro-dev alpine:3.20 ip addr

# 5. nix flake check
nix flake check
```

## Когда использовать `vm`

* Тестирование нового `pro-*.nix`-модуля до применения на
  реальном хосте.
* Воспроизведение бага с `cf19` или `huawei` в чистом окружении.
* Валидация того, что `nix flake update` не ломает сборку, до
  распространения в кластер.
* `huawei-boot.nix` и `cf19-switch-dbus-regression.nix` тесты
  используют `mkVmHost` инфраструктуру внутри.
