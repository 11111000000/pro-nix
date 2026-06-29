+++
title = "Глоссарий"
template = "page.html"
weight = 9

[extra]
tldr = "Проект-специфичная терминология: pro-, composition, recipe, surface, holo, EMCP, ACP, SSOT, и более 30 других терминов."
+++

# Глоссарий

> Ведётся вручную. Термины, которые проект использует в
> специфическом смысле, неочевидном из кода. Не глоссарий Nix или
> Emacs — для них см. upstream-доки.

## A

**Aporetic** — Семейство шрифтов проекта (`Aporetic Sans`,
`Aporetic Sans Mono`). Default для `pro-ui-{code,text}-font-family`
и `conf/fonts.conf`. Fallback на DejaVu, если не в system closure.

**agent** — CLI-тулза, оборачивающая LLM с tool-use протоколом.
Проект использует `pi` (lukasl-dev) и `opencode` (npm-бинарь).
Оба настраиваются через `local-templates/{pi,opencode}/` и
деплоятся через `pro-agent-configs.nix`.

**agent-shell** — Emacs-пакет (сабмодуль `11111000000/agent-shell`),
превращающий Emacs в chat-UI для ACP-говорящих агентов.
Адаптируется `pro-agent-shell.el`.

**ACP** — Agent Client Protocol. JSON-RPC-протокол, на котором
`agent-shell` говорит с бэкендами. Реализация — в
`submodules/acp/` (xenodium/acp.el форк).

**autoload** — `(autoload 'name "file")` откладывает загрузку
функции до первого вызова. pro-*.el-модули используют `###autoload`
для интерактивных команд, которые могут быть не доступны в момент
загрузки.

## B

**Buffer banner** — Transient child-frame вверху выбранного
окна, показывает имя буфера / проект / ветку. Theme-aware
инвертированные цвета, 3-секундный fade-out, debounce 200ms.
Реализация — `emacs/base/modules/pro-buffer-banner.el`.

## C

**Change-Gate** — Четырёхполе-формат в начале каждого PR body:
`Intent:`, `Pressure:`, `Surface:`, `Proof:`. Обеспечивается
`actions/check-change-gate/action.sh`.

**composition** — `hosts/<name>/composition.nix` файл. Импортирует
`system-package-sets-*` и `++`ит их в `environment.systemPackages`.
Composition — **не** NixOS-модуль — это обычное Nix-выражение,
возвращающее attrset.

**contract-тест** — Тест в `tests/contract/*`, проверяющий
структурное свойство конфигурации. Пять contract-тестов сейчас
покрывают сетевой слой (`pro-network-01.sh`), модуль peer
(`pro-peer-01.sh`), tor (`tor-01.sh`), surface-заголовки
(`surface-headers.sh`) и Docker dev chain (`test_docker_dev.sh`).

**CUDA compat** — `nix-cuda-compat.nix` добавляет `types.atom` в
formats-инфраструктуру и `cudaPackages.{cudaFlags, cudaVersion}`
шим. Загружается через `flake.nix#pkgsOverlay`, так что каждый
хост его видит.

## D

**defcustom** — Emacs-механизм для пользовательской настройки.
pro-*.el-модули экспортируют ~70 defcustom'ов в 22 `defgroup`'ах.
Каталог — в [Справочник → defcustom](reference/defcustom.md).

**defgroup** — Логическая группировка для `defcustom` и `defface`.
Проект использует группы вроде `pro`, `pro-ui`, `pro-ui-theme`,
`pro-ui-modeline`, `pro-history`, `pro-buffer-banner`, `pro-docker`,
`pro-emcp`, `pro-exwm`, `pro/chat`, `pro/chat-telega`, `pro-tabs`,
`pro-profiler`, `pro-spell`, `pro-windows`, `pro-completion` и т.д.

**DERP** — Tailscale-протокол relay. Headscale может обслуживать
DERP map; в `modules/headscale.nix` он выключен по умолчанию
(`derp.server.enabled = false`).

**devShell** — `flake.nix#devShells.x86_64-linux.default`. Даёт
Emacs с ~25 emacsPackages на `EMACSLOADPATH`, плюс `ripgrep`, `fd`,
`findutils`, `stress-ng`, `fio`, `powertop`, `iotop`, `lm_sensors`,
`time`, `shellcheck`, `direnv`, `gh`. Скрипт-обёртка в
`$PWD/.pro-emacs-wrapper/emacs-pro` создаётся на `nix develop` с
`-L <pkg>/share/emacs/site-lisp` для каждого overlay-предоставленного
пакета.

## E

**EMCP** — Emacs MCP. HTTP MCP-сервер, живущий на
`http://127.0.0.1:38913/mcp`. Реализован в сабмодуле `emcp`
(codeberg `martenlienen/emcp`), с бэкендом `http-server.el` (тоже
форк того же автора). Emacs-сторона обёрнута `pro-emcp.el` с
4 defcustom'ами (`port`, `host`, `profile` ∈ {`inspect`,
`develop`, `full-control`}, `auto-start`) и 5 командами
(`start`, `stop`, `restart`, `status`, `url`).

**EXWM** — Emacs X Window Manager. EXWM — канонический WM в
pro-nix — скрипт `~/.config/pro/exwm-session` (генерируется
`emacs/exwm.nix:96-176`) запускает Emacs под `systemd-run
--user --scope` с resource-лимитами и IME env-ами.

**exwm-xim** — X Input Method-мост в EXWM. Устанавливается через
`XMODIFIERS=@im=exwm-xim` в session-launcher. **Не** связан с
симуляцией клавиш в Emacs (это в `exwm-input-simulation-keys` в
`pro-exwm-sim.el`).

## F

**FROZEN** — Маркер поверхности в Change-Gate PR body, говорящий:
любое изменение этой поверхности требует migration notes.
Используется для публичных NixOS-опций, на которые downstream-пользователи
(или будущий я) могут полагаться.

**FLUID** — Противоположность: поверхность в работе, может
меняться без migration notes.

## G

**GCM** — Guarded Configuration Modules. Паттерн, используемый в
`pro-emacs.el`, где `pro-compat--add-hook-once`,
`pro-compat--add-to-list-once`, `pro-compat--advice-add-once`
обеспечивают идемпотентность top-level форм под soft-reload.

**guix** — `services.guix.enable = true` установлен глобально;
pro-nix держит Guix как fallback пакетного менеджера для случаев,
когда бинаря нет в nixpkgs.

## H

**headscale** — Самохостящийся Tailscale control-plane. Реализован
в `modules/headscale.nix` с YAML-конфигом, следующим upstream
`headscale` 0.27+ schema. Роль `headscale` назначается ровно
одному хосту — `desktop` — и `lib.mkForce false` на всех остальных.

**holo-verify** — `tools/holo-verify.sh` — top-level
verification-драйвер. Режимы: `unit`/`--quick` (default), `elisp`,
`nixos-fast`, `full`. Сообщает, совпадают ли ссылки `HOLO.md` на
тесты с реальными test-файлами.

**HOLO.md** — «frozen» документ, перечисляющий инварианты,
которые система обещает соблюдать. Не в текущем дереве
исходников (файл упоминается в PR-шаблонах); будет создан.

**HUD** — В `agent-shell-hud` (сабмодуль
`11111000000/agent-shell-hud`), многоязычный heads-up display
(модель + token usage + permissions). Биндинги `C-c a` (menu),
`C-c i` (info), `C-c r` (refresh) внутри `agent-shell-mode`.

## I

**icp** — Identity Control Plane. Не в этом проекте; упоминается
здесь только потому что «icp» иногда появляется в headscale
Tailscale-доках.

**imc** — `systemd --user import-environment`. Вызывается из
`~/.local/bin/pro-emacs-env-fix.sh` (autostart) и из EXWM-session-launcher,
чтобы `DISPLAY`, `XAUTHORITY`, `DBUS_SESSION_BUS_ADDRESS`,
`XDG_CURRENT_DESKTOP` дошли до Emacs под `systemd-run`.

## M

**MagicDNS** — Tailscale-внутренний DNS-резолвер.
`pro-ssh-clients.nix`-сгенерированный `ssh_config.d/pro.conf`
ставит MagicDNS-FQDN первым в списке кандидатов, чтобы SSH-подключение
попало на правильный хост, даже когда LAN mDNS down.

**mkDefault** — Приоритетный маркер на NixOS-опции, default
100. Позволяет другим модулям переопределять без конфликта.
**Анти-паттерн:** использовать его для обязательных
`environment.systemPackages` (plain assignment — обязательно;
mkDefault — для дефолтов).

**mkForce** — Приоритет 50, побеждает plain и `lib.mkDefault`.
Используется в `hosts/*/configuration.nix`, чтобы сознательно
переопределить то, что даёт глобальный модуль. Канонический
`cf19`/`huawei` `headscale.enable = lib.mkForce false`.

**mkVmHost** — Второй host-конструктор в `flake.nix:92-102`. **Не**
импортирует `configuration.nix`. Используется для `vm`, чтобы
держать eval минимальным и не тянуть в `headscale.nix`,
`pro-network.nix` и т.д. Побочный эффект — `headscale.enable` **даже
не валидный атрибут** в eval `vm` — см.
`hosts/vm/configuration.nix:35-37`.

**Mole** — В Emacs-терминологии: mode + role pair (например,
`pro-c-mole`, `pro-python-mole`). pro-nix не использует термин
сильно, но `pro-c.el`, `pro-python.el` и т.д. имеют контракт
«set up the mole on `xxx-mode-hook`».

## N

**NSP** — NSS-плагин. Пакет `nss-mdns` — это NSP для `.local`
mDNS-резолва на glibc-системах. Без него `getent hosts
<name>.local` пусто, даже когда Avahi публикует имя.

## O

**opencode** — Второй AI-агент, npm-бинарь. `opencode-stub.nix`
overlay скачивает tarball и patchelf'ит под glibc. Bwrap-вариант
через `opencodeBwrap.homeManagerModules.default`.

**overlay** — Функция `(final: prev: { ... })`, патчащая пакетный
сет. Пять overlays: `emacs-extra`, `opencode-stub`, `pi-acp`,
`mirrors`, `github-proxy`. Применяются через
`flake.nix#pkgsOverlay`.

## P

**pending binding** — Глобальная клавиша, ссылающаяся на команду
из пакета, ещё не загруженного. `pro-keys-pending-bindings`
хранит её; когда пакет становится доступен (MELPA install,
Nix-provided load), биндинг применяется.

**pi** — Основной CLI-агент кодинга. `lukasl-dev/pi.nix` даёт
NixOS-модуль (`pi.nixosModules.default`), подключённый глобально.
`pi` запускается через `pi-acp` (svkozak/pi-acp v0.0.27) для
ACP-коммуникации.

**pi-crew** — Multi-agent orchestration npm-пакет, который
pro-nix **не** устанавливает (исключён из
`local-templates/pi/settings.json`).

**pro-** — Префикс проекта. Используется для NixOS-модулей
(`modules/pro-*.nix`) и Emacs-модулей
(`emacs/base/modules/pro-*.el`). Префикс **информативный**:
`pro-`-файлы принадлежат pro-nix, а не upstream-пакетам.

**providedPackages** — Список имён Emacs-пакетов (58), которые
Nix **предоставляет** в closure. Хранится в
`emacs/core.nix#pro.emacs.providedPackages` и становится виден
Emacs через `EMACSLOADPATH`.

## R

**recipe** — `nix/emacs-recipes/*.nix` файл. Каждый —
`stdenv.mkDerivation`, собирающий один Emacs-пакет из сабмодуля
или внешнего источника. Overlays подтягивают recipes через
`emacsPackages.elpaBuild` или `emacsPackages.trivialBuild`-эквиваленты.

**resolve** — per-candidate fallback в `pro-ssh-clients.nix`:
каждый candidate hostname в сгенерированном `Host`-блоке имеет
свой `ConnectTimeout`, так что мёртвый `.local` не блокирует
рабочий tailnet-FQDN.

## S

**searxng** — Самохостящийся мета-поисковик, запускаемый
`modules/searxng.nix`. Сейчас **выключен** на верхнем уровне
(`services.searxng.enable = lib.mkForce false` в
`configuration.nix:85`) из-за бага `settings.yml`, вызывающего
restart loop и усиливающего boot/switch-таймауты D-Bus/systemd
на `cf19`. TODO: починить и re-enable.

**SearXNG-secret** — `secret_key` генерируется в activation-time
и пишется в `/var/lib/searxng/env` (chmod 0400, вне
`/nix/store`). Ссылается как `EnvironmentFile` systemd-юнитом.
Литерал `$SEARXNG_SECRET_KEY` в рендеренном `settings.yml` —
SearXNG разворачивает из env-файла.

**shaoline** — Минималистичный mode-line. Сабмодуль
`11111000000/shaoline`. Установлен как `pro-ui-modeline-style =
'shaoline` в `pro-ui.el`.

**SSOT** — Single Source of Truth. Три в этом проекте: `pro.hosts`
(хосты), `emacs-keys.org` (клавиши), `local.nix` (per-host секреты).

**soft reload** — `M-x pro/reload-config` (C-x M-c) переоценивает
все загруженные модули в месте. `C-u` re-evals `site-init.el` первым
(full reload). Модули, владеющие persistent state, регистрируют
teardown на `pro--after-reload-hook`, чтобы soft reload
пересоздавал их state из свежезагруженного кода.

**surface** — Набор публичных атрибутов, которые модуль
экспортирует. `tools/surface-lint.sh` обеспечивает пятисекционную
шапку (Назначение / Цель / Контракт / Побочные эффекты / Proof)
на каждом `modules/*.nix`.

## T

**tailscale** — Tailscale-клиент. `services.tailscale.enable` **не**
установлен глобально в этом проекте (требует auth-key, ломает
`nixos-rebuild` без секрета). Tailnet-связность даётся через
`headscale`.

**tao-yang / tao-yin** — Дефолтные Emacs-темы.
`pro-ui-default-theme = 'tao-yang` — default (светлая);
альтернатива — `'tao-yin` (тёмная). Обе из сабмодуля
`tao-theme` (`11111000000/tao-theme-emacs`).

**telega** — Telegram-клиент для Emacs. Реализован в
`submodules/telega.el/` (zevlg/telega.el), с отдельным
TDLib-бинарём `telega-server`, собираемым
`nix/emacs-recipes/telega-server.nix`. Emacs-сторона обёрнута
`pro-telega.el` и `pro-chat.el`.

**TORSOCKS** — `torsocks` оборачивает системные вызовы в
LD_PRELOAD-шим, форсирующий подключения через локальный SOCKS5
на 9050. `bin/torwrap` использует его (или `proxychains4` как
fallback) для запуска произвольных команд через Tor.

## W

**WAYLAND_NO_HARDWARE_CURSORS** — Установлен как
`WLR_NO_HARDWARE_CURSORS=1` в Sway-сессии. Intel workaround для
hw-курсоров на multi-monitor и after-sleep.

**winner-mode** — Встроенный Emacs minor mode, записывающий
window-конфигурации и позволяющий undo/redo их. Забинден на
`<XF86Back>` / `<XF86Forward>` в `emacs-keys.org`.

## X

**xdg.portal** — `xdg-desktop-portal-gtk` установлен как
`configPackages` и `extraPortals` на верхнем уровне. EXWM-minimal
тоже его добавляет. Реализация `gtk` предпочтительна для
стабильности, перед `xdg-desktop-portal-kde` или `-gnome`.

**Xresources** — `conf/Xresources` — единственный source of
truth для Emacs/URxvt/XTerm/Xmessage/Xpdf Xresources. Деплоится
в `/etc/X11/Xresources` через
`configuration.nix#environment.etc."X11/Xresources".text`.
`exwm-session` мерджит его с `xrdb -merge` при старте, так что
первый фрейм flicker-free.

## Z

**zram** — Compressed-RAM swap. `services.zramSlice.enable` и
`size = "auto"` (50% RAM, cap 16384 MB) на `desktop` и `huawei`.
Не на `cf19` (уже есть дисковый swap) или `vm`.
