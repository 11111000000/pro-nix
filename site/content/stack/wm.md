+++
title = "Оконные менеджеры"
template = "page.html"
weight = 4

[extra]
tldr = "EXWM в Emacs, Sway на Wayland, i3 на X11. Одна клавиатурная раскладка во всех трёх: Mod4+hjkl фокус, Mod4+1..9 рабочий стол, Mod4+Return терминал, Mod4+Space app launcher."

[[extra.next]]
title = "Приватность и Tor"
url = "/stack/privacy/"

[[extra.next]]
title = "Хосты"
url = "/hosts/"
+++

# Оконные менеджеры

Проект поддерживает **три** оконных менеджера с общей
клавиатурной философией:

* **EXWM** — Emacs X Window Manager. Используется как основная
  сессия на `cf19` и `desktop` (через `profile-exwm-minimal.nix`).
* **Sway** — Wayland-композитор. Используется на `huawei` и как
  fallback на `desktop` / `cf19` (оба импортируют
  `session-sway.nix`).
* **i3** — X11 tiling WM. Та же fallback-роль, что и Sway;
  настраивается в `session-i3.nix`.

EXWM-клавиатура — каноническая. Sway и i3 сконфигурированы так,
чтобы следовать ей; мышечная память переносится чисто.

## Общая клавиатурная карта

| Действие | EXWM | Sway | i3 |
|----------|------|------|-----|
| Фокус влево/вниз/вверх/вправо | `s-h/j/k/l` | `Mod4+h/j/k/l` | `Mod4+h/j/k/l` |
| Переместить окно | `s-H/J/K/L` | `Mod4+Shift+h/j/k/l` | `Mod4+Shift+h/j/k/l` |
| Рабочий стол 1..9 | `s-1`..`s-9` | `Mod4+1`..`Mod4+9` | `Mod4+1`..`Mod4+9` |
| Переместить окно на рабочий стол | — | `Mod4+Shift+1`..`9` | `Mod4+Shift+1`..`9` |
| Терминал | `C-c t o` (multi-vterm-project) | `Mod4+Return` (foot) | `Mod4+Return` (xterm) |
| Запуск приложения | `s-x` (consult) | `Mod4+Space` (wofi) | `Mod4+Space` (dmenu) |
| Закрыть окно | `C-x k 0` | `Mod4+q` | `Mod4+q` |
| Перезагрузить WM-конфиг | — | `Mod4+Shift+c` | `Mod4+Shift+c` |
| Перезапустить WM | — | `Mod4+Shift+r` | `Mod4+Shift+r` |
| Fullscreen | (Emacs full-buffer) | `Mod4+f` | `Mod4+f` |
| Lock | (loginctl) | `Mod4+Escape` (swaylock) | — |
| Сплит горизонтально/вертикально | (Emacs) | `Mod4+b` / `Mod4+v` | `Mod4+b` / `Mod4+v` |
| Layout stacking/tabbed | — | `Mod4+s` / `Mod4+w` | `Mod4+s` / `Mod4+w` |
| Toggle split | — | `Mod4+e` | `Mod4+e` |

> `Mod4+d` в Sway/i3 **намеренно не забиндена** — она бы
> конфликтовала с `EXWM s-d = treemacs`.

## EXWM

EXWM — самый opinionated из трёх: Emacs становится оконным
менеджером. Session-launcher в `emacs/exwm.nix:96-176` делает
следующее по порядку:

1. Дописывает startup-лог в
   `~/.cache/emacs-startup/gdm-exwm.log`.
2. `eval $(ssh-agent -s)`, `export SSH_AUTH_SOCK`.
3. `xset -b` (выключить bell), `xhost +SI:localuser:$USER` и
   `+SI:localuser:root` (разрешить локальные X-подключения для
   `emacsclient`).
4. Экспорт IME-env: `XMODIFIERS=@im=exwm-xim`,
   `GTK_IM_MODULE=xim`, `QT_IM_MODULE=xim`,
   `CLUTTER_IM_MODULE=xim`, `GTK_KEY_THEME=Emacs`.
5. `LSP_USE_PLISTS=true` (Haskell LSP quirk).
6. `xsetroot -cursor_name left_ptr` и `VISUAL=emacsclient`.
7. `xrdb -merge /etc/X11/Xresources` (системный) затем
   `~/.Xresources` (HM override). Порядок важен: сначала
   системный, пользователь выигрывает на конфликте.
8. Re-launch rescue xbindkeys grab (идемпотентно — `~/.xprofile`
   уже стартовал его под lightdm, это защитный pgrep для
   пользователей `startx`).
9. `systemctl --user import-environment` для X11-переменных.
10. `exec systemd-run --user --scope -p MemoryMax=2G -p MemoryHigh=1800M
    -p CPUQuota=120% -p CPUWeight=200 -E XDG_CURRENT_DESKTOP=EXWM
    -E DISPLAY ... exec emacs --init-directory $HOME/.config/emacs`.

Resource-лимиты (`MemoryMax`, `MemoryHigh`, `CPUQuota`, `CPUWeight`)
не дают взбесившемуся Emacs положить всю машину.

### Специфичный для EXWM Emacs-код

* `emacs/base/modules/pro-exwm.el` — `pro-exwm-start-session`,
  `pro/exwm-urxvt-toggle` (urxvt sidebar), autostart-хелперы,
  prefix-клавиши для IME.
* `emacs/base/modules/pro-exwm-sim.el` — `exwm-input-simulation-keys`,
  чтобы Emacs-стиль навигации работал в X11-приложениях
  (например, C-n/C-p в Telegram).
* `modules/pro-emacs-rescue.nix` — `Control+Alt+Shift+r` (по умолчанию)
  → xbindkeys grab **до** EXWM (в `~/.xprofile`) → emacsclient probe →
  poke зависший `*package*` / `*elpaca*` буфер → `kill -USR2` →
  `systemd-run --user --scope` restart. 3-секундный cooldown.
  notify-send при успехе.

## Sway (Wayland)

`modules/session-sway.nix` оборачивает Sway-сессию в
`dbus-run-session` (обход краша `wl_compositor` ~2 с после старта)
и устанавливает `WLR_NO_HARDWARE_CURSORS=1` (Intel hw-cursor fix
для multi-monitor и after-sleep).

Общий конфиг — в `conf/sway-config.in`. Sway-специфичное:

* `Mod4` = Super.
* `xkb_layout "us,ru"`, `xkb_options "ctrl:nocaps,grp:toggle,grp_led:caps"`
  (CapsLock становится Ctrl, Right Alt переключает, светодиод
  CapsLock показывает активную группу).
* Touchpad: `tap enabled`, `natural_scroll enabled`.
* `exec waybar`, `exec mako` (status + notifications).
* `gaps inner 4`, `gaps outer 4`, `default_border pixel 2`
  (визуальное разделение между окнами).
* `seat seat0 cursor hide_when_typing enabled`.

Пакеты: `sway`, `waybar`, `mako`, `swaybg`, `swaylock`,
`swayidle`, `wl-clipboard`, `wofi`, `foot`, `grim`, `slurp`.

## i3 (X11)

`modules/session-i3.nix`. Конфиг (`conf/i3-config.in`) зеркалит
Sway-layout, но использует X11-примитивы. `i3-nagbar` бандлится с
`i3` (отдельного пакета нет). Статус-бар — `polybar` (конфиг в
`environment.etc."polybar/config.ini".text`).

Пакеты: `i3`, `i3status`, `dmenu`, `xterm`, `dex`, `feh`, `dunst`,
`polybar`, `libnotify`.

## Xresources

`conf/Xresources` — единственный источник правды для X11
визуальных настроек. Определяет:

* `Xft.*` дефолты (antialias on, hintfull, lcdfilter lcddefault, rgb).
* `Emacs.font: Aporetic Sans Mono 14`, `Emacs.useXIM: false`
  (чтобы exwm-xim был единственным XIM-сервером).
* URxvt: `Terminus 14`, foreground `#b0b0b0`, background `#000000`,
  cursor `#88ff88`, 16-цветная палитра
  `#1c1c1c, #c25c5c, #5cc25c, #c2c25c, #5c5cc2, #c25cc2, #5cc2c2,
  #c0c0c0, #666666, #d87575, #75d875, #d8d875, #7575d8, #d875d8,
  #75d8d8, #e5e5e5`.
* XTerm fallback (та же палитра).
* Xmessage (диалоги): `#3c3c3c` фон, `#c2c2c2` foreground.
* Xpdf: `Aporetic Sans 12`.

Палитра — это **design system** и для этого сайта; CSS в
`site/static/css/main.css` использует те же 16 цветов.

## Per-host WM-назначение

| Хост | Основной WM | Также доступен |
|------|-------------|-----------------|
| `desktop` | EXWM (через `profile-exwm-minimal.nix`) | Sway, i3, Cinnamon (mkForce false) |
| `cf19` | EXWM (через `profile-exwm-minimal.nix`) | Sway, i3, Cinnamon (mkForce false), fbterm-tty2 (mkForce false) |
| `huawei` | Sway (ручной старт, без EXWM-minimal import) | i3, heavy-desktop (без Cinnamon) |
| `vm` | нет (`services.xserver.enable = mkForce false`) | — |

Хосты импортируют и `session-sway.nix`, и `session-i3.nix`, так что
пользователь выбирает в GDM-сессион-чузере.
