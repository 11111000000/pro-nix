+++
title = "Composition-файлы"
template = "page.html"
weight = 3

[extra]
tldr = "system-package-sets-* — функции, не модули. Хосты импортируют их и ++ в environment.systemPackages. Чистый способ делить списки пакетов между хостами."

[[extra.next]]
title = "Загрузка Emacs"
url = "/architecture/emacs-base/"

[[extra.next]]
title = "Хосты"
url = "/hosts/"
+++

# Composition-файлы

**Composition-файл** — это `modules/system-package-sets-*.nix`. Это
**не** NixOS-модуль — он не объявляет опции, не появляется в
`imports` и не вычисляется как часть module-конфигурации. Это
обычная функция:

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

`composition.nix` хоста импортирует один или несколько из них,
вызывает с правильным `pkgs`, и `++`ит результирующий
`somePackages`-список в `environment.systemPackages`.

## Зачем этот паттерн

Три причины:

1. **Никакой merge-семантики.** `environment.systemPackages` — это
   список, и конкатенация списков однозначна. Никакого
   `mkDefault` / `mkForce` взаимодействия — каждый `++` просто
   дописывает. Дубликаты дедапятся в build-time.
2. **Переиспользование между хостами.** Тот же `runtime`-сет на
   `cf19`, `huawei` и `vm`. Тот же `desktopHeavy` на `huawei` и
   (в будущем) `desktop`. Без функциональной индирекции пришлось бы
   копи-пастить списки.
3. **Нет случайного связывания.** Потому что это не модуль, он
   не может объявлять `options`, не может читать `config`, не может
   иметь side-effects. Чистая функция `pkgs` → `attrsOf (listOf
   package)`.

## 8 composition-файлов

| Файл | Возвращает | Содержимое |
|------|------------|-----------|
| `system-package-sets-runtime.nix` | `runtimePackages` | Базовый runtime (bashInteractive, openssh, python3, dbus, gawk, kbd, mc, emacs, rxvt-unicode, curl, wget, jq, just, git, gh, ripgrep, fd, tmux, tree, htop, lsof, alsa-utils, beep, …) |
| `system-package-sets-dev.nix` | `devPackages`, `llmLabCmd`, `pythonCmd` | Dev toolchain (direnv, shellcheck, shfmt, bat, tldr, pipx, nodejs_20, …), `llm-lab` Python-обёртка с jupyter/transformers/datasets, … |
| `system-package-sets-exwm.nix` | `exwmPackages` | X11 / EXWM UI-хелперы (xset, xhost, setxkbmap, wmname, xbindkeys, xdotool, xclip, xauth, feh, xterm, scrot, dunst, flameshot, …) |
| `system-package-sets-desktop-heavy.nix` | `desktopHeavyPackages` | Chromium (с `systemd-run --user --scope -p MemoryMax=4500M -p CPUQuota=90%`), Firefox (2.5G / 90%), telegram-desktop, element-desktop, jami, ffmpeg-full, steam, steam-run, … |
| `system-package-sets-lsp.nix` | `lspPackages` | pyright, jdtls, rust-analyzer, gopls, bash-language-server (все `maybe`'нуты, так что отсутствующий upstream возвращает `[]`) |
| `system-package-sets-media.nix` | `mediaPackages` | ffmpeg-full, mpv, ffmpegthumbnailer |
| `system-package-sets-privacy.nix` | `privacyPackages` | tor, torsocks, obfs4, snowflake, nyx, onionshare, dnscrypt-proxy, wireguard-tools, yggdrasil, i2p, proxychains, mullvad-vpn, tor-browser |
| `system-package-sets-tor.nix` | `torControlPackages` | `pro-tor` (writeShellApplication), `torwrap` (writeShellApplication), torsocks, proxychains |

## Чтение composition-файла

Пример — `system-package-sets-tor.nix`:

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

`writeShellApplication` — nixpkgs-хелпер «собрать shell-скрипт с
правильным shebang и runtime-зависимостями». Чтение тела скрипта
из `../../scripts/pro-tor` держит source of truth в одном месте.

## Как хост использует composition-файл

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

Паттерн: `let`-блок импортирует каждый composition-файл с
`inherit pkgs`, затем `environment.systemPackages` — это
`++`-конкатенация релевантных `.fooPackages` атрибутов.

## Добавление нового composition-файла

1. Создай `modules/system-package-sets-<name>.nix` по шаблону функции.
2. Реши, каким хостам он нужен.
3. Добавь `import ../../modules/system-package-sets-<name>.nix { inherit pkgs; }` и `++ X.<attr>` в каждый `composition.nix` нужного хоста.
4. Опционально добавь в `tools/surface-lint.sh` и
   `tools/holo-verify.sh`, чтобы контракт поддерживался.

## Удаление composition-файла

Composition-файл, который никто не импортирует — мёртвый код.
Детекция:

```bash
rg -l "system-package-sets-<name>" hosts/    # должно быть пусто
```

Если пусто, удали файл. Нет `imports`-списка для чистки, потому
что файл **никогда** не в `imports`.

> **Различие `pro-*.nix` и `system-package-sets-*.nix` —
> известная мина.** Новички иногда кладут `system-package-sets-*`
> в `imports` — файл вычисляется как NixOS-модуль (строка), что
> падает с «expected a module attribute set». Фикс — импортировать
> из `composition.nix`, не из `configuration.nix`.
