+++
title = "Window managers"
template = "page.html"
weight = 4

[extra]
tldr = "EXWM in Emacs, Sway on Wayland, i3 on X11. One keyboard map across all three: Mod4+hjkl focus, Mod4+1..9 workspace, Mod4+Return terminal, Mod4+Space app launcher."

[[extra.next]]
title = "Privacy & Tor"
url = "/stack/privacy/"

[[extra.next]]
title = "Hosts"
url = "/hosts/"
+++

# Window managers

The project supports **three** window managers, with one shared keyboard
philosophy:

* **EXWM** — Emacs X Window Manager. Used as the primary session on
  `cf19` and `desktop` (through `profile-exwm-minimal.nix`).
* **Sway** — Wayland compositor. Used on `huawei` and as a fallback on
  `desktop` / `cf19` (both have `session-sway.nix` available).
* **i3** — X11 tiling WM. Same fallback role as Sway; configured in
  `session-i3.nix`.

The EXWM keyboard map is the canonical one. Sway and i3 are configured
to match it so the muscle memory transfers cleanly.

## The shared key map

| Action | EXWM | Sway | i3 |
|--------|------|------|-----|
| Focus left/down/up/right | `s-h/j/k/l` | `Mod4+h/j/k/l` | `Mod4+h/j/k/l` |
| Move window | `s-H/J/K/L` | `Mod4+Shift+h/j/k/l` | `Mod4+Shift+h/j/k/l` |
| Workspace 1..9 | `s-1`..`s-9` | `Mod4+1`..`Mod4+9` | `Mod4+1`..`Mod4+9` |
| Move window to workspace | — | `Mod4+Shift+1`..`9` | `Mod4+Shift+1`..`9` |
| Terminal | `C-c t o` (multi-vterm-project) | `Mod4+Return` (foot) | `Mod4+Return` (xterm) |
| App launcher | `s-x` (consult) | `Mod4+Space` (wofi) | `Mod4+Space` (dmenu) |
| Close window | `C-x k 0` | `Mod4+q` | `Mod4+q` |
| Reload WM config | — | `Mod4+Shift+c` | `Mod4+Shift+c` |
| Restart WM | — | `Mod4+Shift+r` | `Mod4+Shift+r` |
| Fullscreen | (Emacs full-buffer) | `Mod4+f` | `Mod4+f` |
| Lock | (loginctl) | `Mod4+Escape` (swaylock) | — |
| Split horizontal/vertical | (Emacs) | `Mod4+b` / `Mod4+v` | `Mod4+b` / `Mod4+v` |
| Layout stacking/tabbed | — | `Mod4+s` / `Mod4+w` | `Mod4+s` / `Mod4+w` |
| Toggle split | — | `Mod4+e` | `Mod4+e` |

> The `Mod4+d` shortcut in Sway/i3 is **deliberately not bound** — it
> would conflict with `EXWM s-d = treemacs`.

## EXWM

EXWM is the most opinionated of the three: it makes Emacs the window
manager. The session launcher is in
`emacs/exwm.nix:96-176` and does the following in order:

1. Append a startup log to `~/.cache/emacs-startup/gdm-exwm.log`.
2. `eval $(ssh-agent -s)`, `export SSH_AUTH_SOCK`.
3. `xset -b` (kill terminal bell), `xhost +SI:localuser:$USER` and
   `+SI:localuser:root` (allow local X connections for `emacsclient`).
4. Export IME env vars: `XMODIFIERS=@im=exwm-xim`, `GTK_IM_MODULE=xim`,
   `QT_IM_MODULE=xim`, `CLUTTER_IM_MODULE=xim`, `GTK_KEY_THEME=Emacs`.
5. `LSP_USE_PLISTS=true` (Haskell LSP quirk).
6. `xsetroot -cursor_name left_ptr` and `VISUAL=emacsclient`.
7. `xrdb -merge /etc/X11/Xresources` (system) then `~/.Xresources` (HM
   override). Order matters: system first, user wins on conflict.
8. Re-launch the rescue xbindkeys grab (idempotent — `~/.xprofile`
   already started it under lightdm, this is a defensive pgrep for
   `startx` users).
9. `systemctl --user import-environment` for the X11 variables.
10. `exec systemd-run --user --scope -p MemoryMax=2G -p MemoryHigh=1800M
    -p CPUQuota=120% -p CPUWeight=200 -E XDG_CURRENT_DESKTOP=EXWM -E DISPLAY
    ... exec emacs --init-directory $HOME/.config/emacs`.

The resource limits (`MemoryMax`, `MemoryHigh`, `CPUQuota`, `CPUWeight`)
prevent a runaway Emacs from taking down the whole machine.

### EXWM-specific Emacs code

* `emacs/base/modules/pro-exwm.el` — `pro-exwm-start-session`,
  `pro/exwm-urxvt-toggle` (urxvt sidebar), autostart helpers, prefix
  keys for the IME.
* `emacs/base/modules/pro-exwm-sim.el` — `exwm-input-simulation-keys`
  so Emacs-style navigation works in X11 apps (e.g. C-n/C-p in Telegram).
* `modules/pro-emacs-rescue.nix` — `Control+Alt+Shift+r` (default) →
  xbindkeys grab **before** EXWM (in `~/.xprofile`) → emacsclient probe →
  poke stuck `*package*` / `*elpaca*` buffer → `kill -USR2` →
  `systemd-run --user --scope` restart. 3-second cooldown. notify-send
  on success.

## Sway (Wayland)

`modules/session-sway.nix` wraps the Sway session in `dbus-run-session`
(a workaround for a `wl_compositor` crash ~2 s after start) and sets
`WLR_NO_HARDWARE_CURSORS=1` (Intel hardware-cursor fix for multi-monitor
and after-sleep glitches).

The shared config is in `conf/sway-config.in`. Sway-specific bits:

* `Mod4` = Super.
* `xkb_layout "us,ru"`, `xkb_options "ctrl:nocaps,grp:toggle,grp_led:caps"`
  (CapsLock becomes Ctrl, Right Alt toggles, CapsLock LED shows active
  group).
* Touchpad: `tap enabled`, `natural_scroll enabled`.
* `exec waybar`, `exec mako` (status + notifications).
* `gaps inner 4`, `gaps outer 4`, `default_border pixel 2` (visual
  separation between windows).
* `seat seat0 cursor hide_when_typing enabled`.

Packages: `sway`, `waybar`, `mako`, `swaybg`, `swaylock`, `swayidle`,
`wl-clipboard`, `wofi`, `foot`, `grim`, `slurp`.

## i3 (X11)

`modules/session-i3.nix`. The config (`conf/i3-config.in`) mirrors the
Sway layout but uses X11 primitives. `i3-nagbar` is bundled with `i3`
(no separate package). The status bar is `polybar` (config in
`environment.etc."polybar/config.ini".text`).

Packages: `i3`, `i3status`, `dmenu`, `xterm`, `dex`, `feh`, `dunst`,
`polybar`, `libnotify`.

## Xresources

`conf/Xresources` is the single source of truth for X11 visual settings.
It defines:

* `Xft.*` defaults (antialias on, hintfull, lcdfilter lcddefault, rgb).
* `Emacs.font: Aporetic Sans Mono 14`, `Emacs.useXIM: false` (so
  exwm-xim is the sole XIM server).
* URxvt: `Terminus 14`, foreground `#b0b0b0`, background `#000000`,
  cursor `#88ff88`, the 16-color palette `#1c1c1c, #c25c5c, #5cc25c,
  #c2c25c, #5c5cc2, #c25cc2, #5cc2c2, #c0c0c0, #666666, #d87575, #75d875,
  #d8d875, #7575d8, #d875d8, #75d8d8, #e5e5e5`.
* XTerm fallback (same palette).
* Xmessage (dialogs): `#3c3c3c` background, `#c2c2c2` foreground.
* Xpdf: `Aporetic Sans 12`.

The palette is the **design system** for this site too — the CSS in
`site/static/css/main.css` reuses the same 16 colors.

## Per-host WM assignment

| Host | Primary WM | Also available |
|------|-------------|----------------|
| `desktop` | EXWM (via `profile-exwm-minimal.nix`) | Sway, i3, Cinnamon (mkForce false) |
| `cf19` | EXWM (via `profile-exwm-minimal.nix`) | Sway, i3, Cinnamon (mkForce false), fbterm-tty2 (mkForce false) |
| `huawei` | Sway (manual start, no EXWM-minimal import) | i3, heavy-desktop (no Cinnamon) |
| `vm` | none (`services.xserver.enable = mkForce false`) | — |

Hosts import both `session-sway.nix` and `session-i3.nix` so the
user can pick at the GDM session chooser.
