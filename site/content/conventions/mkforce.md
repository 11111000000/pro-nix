+++
title = "mkForce"
template = "page.html"
weight = 2

[extra]
tldr = "Три приоритета NixOS module system: plain (обязательно), mkDefault (по умолчанию), mkForce (per-host override). lib.mkDefault НЕ использовать для обязательных пакетов."

[[extra.next]]
title = "Change-Gate"
url = "/conventions/change-gate/"
+++

# mkForce

Три приоритета для `environment.systemPackages` и других
NixOS-опций: plain, `lib.mkDefault`, `lib.mkForce`.

## Три приоритета

```nix
# Plain assignment (default priority 100, списки склеиваются)
environment.systemPackages = with pkgs; [ vim git ripgrep ];

# mkDefault (priority 100, но явно "это дефолт")
environment.systemPackages = lib.mkDefault (with pkgs; [ vim ]);

# mkForce (priority 50, побеждает plain + mkDefault)
environment.systemPackages = lib.mkForce (with pkgs; [ neovim ]);
```

## Правила

* **Plain assignment** — для **обязательных** пакетов. Модуль
  утверждает, что они должны быть в системном closure. Большинство
  `pro-*.nix` использует это.

* **`lib.mkDefault`** — для **дефолтов**, которые пользователь
  (или другой модуль) может переопределить без конфликта.
  Уместен только для опц. наборов, которые пользователь может
  захотеть переопределить.

* **`lib.mkForce`** — для **per-host переопределений**.
  Используется в `hosts/*/`, чтобы сказать «этот хост сознательно
  не хочет то, что даёт глобальный модуль». Классика —
  `headscale.enable = lib.mkForce false` на `cf19` / `huawei`.

## Главный анти-паттерн

**`lib.mkDefault` для *обязательного* списка пакетов.** Потому что
`lib.mkDefault` — это само по себе приоритет-100-утверждение, любое
обычное присвоение в другом модуле тихо его заменяет, и пакеты
пропадают. Линт `tools/mkforce-lint.sh` считает вхождения; если
видите `mkDefault` для package list — это повод остановиться.

## Примеры

### Правильно: `lib.mkForce false` в per-host override

```nix
# hosts/cf19/configuration.nix
headscale.enable = lib.mkForce false;
# hosts/huawei/configuration.nix
headscale.enable = lib.mkForce false;
```

Только `desktop` имеет `headscale.enable = true` (default в
`flake.nix`). На ноутбуках — `lib.mkForce false`. Забыть `mkForce`
тихо стартует конкурирующий control plane.

### Правильно: `lib.mkDefault` для опц. фичи

```nix
# modules/pro-wifi-watchdog.nix
enable = lib.mkEnableOption "..." // { default = true; };
```

Здесь `default = true` означает «по умолчанию включено». Хосты
могут отключить через `pro.wifi.watchdog.enable = false` (без
`mkForce`, потому что default уже `true`).

### Правильно: plain для обязательного пакета

```nix
# modules/packages-runtime.nix
environment.systemPackages = with pkgs; [
  bashInteractive openssh python3 ...
];
```

Это **обязательный** runtime, модуль утверждает, что он должен
быть. Plain — правильный выбор.

### Неправильно: `lib.mkDefault` для обязательного пакета

```nix
# ❌ НЕ ДЕЛАЙТЕ ТАК
environment.systemPackages = lib.mkDefault (with pkgs; [ bashInteractive openssh ]);
```

Другой модуль с plain-присвоением тихо заменит этот список.
Пакеты пропадут. Это классический «невидимый» баг.

## Детекция

`tools/mkforce-lint.sh` (неблокирующий):

```bash
./tools/mkforce-lint.sh
# Warning: 5 systemPackages declared in modules/
# Warning: 3 lib.mkForce occurrences in modules/
```

Скрипт не валит CI, но печатает warnings. Используется, чтобы
привлечь внимание к «что-то подозрительно».

`tests/contract/unit/05-mkforce-lint-test.sh` — smoke-тест, что
скрипт запускается без падения.

## Где ещё работает тот же приоритет

`lib.mkDefault` / `lib.mkForce` работают для **любой** опции
NixOS-модуля, не только `systemPackages`. Например:

* `services.tor.enable = lib.mkForce false` (per-host override)
* `pro.emacs.gui.enable = lib.mkDefault true` (по умолчанию GUI
  включён, но Termux-хост его отключает через `mkForce false`)
* `networking.firewall.allowedUDPPorts = lib.mkDefault [ 5353 ]` (Avahi
  порт по умолчанию; хосты могут переопределить)

Механика — та же: `mkForce` (50) выигрывает у plain/mkDefault
(100). Наоборот — никогда.

## Резюме

| Что | Приоритет | Когда |
|-----|-----------|--------|
| Plain | 100 | Обязательные пакеты, обязательные сервисы |
| `lib.mkDefault` | 100 | Дефолты, которые пользователь может переопределить |
| `lib.mkForce` | 50 | Per-host override, сознательное исключение из default |

Если сомневаетесь — plain. Переход к `mkForce` делается явно в
`hosts/*/`, когда возникает необходимость.
