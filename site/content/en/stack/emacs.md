+++
title = "Emacs layer"
template = "page.html"
weight = 2

[extra]
tldr = "Emacs 30, ~60 pro-*.el modules, four-phase bootstrap, soft-reload contract, tao-yang theme, Aporetic Sans, custom buffer banner, vertico+corfu+cape+orderless, the 'tao' aesthetic."

[[extra.next]]
title = "AI agents layer"
url = "/stack/ai/"

[[extra.next]]
title = "Emacs bootstrap"
url = "/architecture/emacs-base/"
+++

# Emacs layer

The editor layer is **Nix-provided**. ~60 Emacs packages come from
`pkgs.emacsPackages` and are made visible to Emacs at build time through
`EMACSLOADPATH`. The user does not need to interact with `package.el` —
`pro-packages.el` is policy-driven: Nix first, then MELPA fallback, then
package-vc, with `~/.config/emacs/decisions.el` as the override.

## What ships in the closure

`emacs/core.nix#pro.emacs.providedPackages` — 60+ names including
`magit`, `vertico`, `vertico-sort`, `orderless`, `marginalia`, `gptel`,
`consult`, `consult-dash`, `dash-docs`, `consult-eglot`, `consult-yasnippet`,
`corfu`, `cape`, `kind-icon`, `avy`, `expand-region`, `yasnippet`,
`projectile`, `treemacs`, `consult-projectile`, `elfeed`, `eglot`,
`rainbow-delimiters`, `nix-mode`, `markdown-mode`, `mmm-mode`, `org`,
`ob-mermaid`, `vterm`, `multi-vterm`, `eshell-toggle`, `ace-window`,
`undo-tree`, `haskell-mode`, `haskell-snippets`, `which-key`,
`which-key-posframe`, `eldoc-box`, `keyfreq`, `helpful`, `popper`,
`buffer-expose`, `buffer-move`, `golden-ratio`, `embark`,
`embark-consult`, `exwm`, `xelb`, `agent-shell`, `agent-shell-hud`, `acp`,
`emcp`, `telega`, `transient`, `visual-fill-column`, `pro-tabs`,
`goto-chg`, `docker`, `tao-theme`, `shaoline`, `nerd-icons`,
`all-the-icons`, `treemacs-icons-dired`, `eldoc-box`.

The `providedPackages` is **the** catalogue. It is regenerated into
`~/.config/emacs/provided-packages.el` on every activation
(`emacs/core.nix:194-196`), so a fresh host has the same set as
`desktop` from the first `pro-emacs-base-start`.

## The four-phase bootstrap

| Phase | File | When it runs |
|-------|------|--------------|
| 1. `early-init.el` | `emacs/base/early-init.el` | Before package system starts |
| 2. `init.el` | `emacs/base/init.el` | Main init; sets `user-emacs-directory` |
| 3. `site-init.el` | `emacs/base/site-init.el` | Module manifest + resolver + key loader |
| 4. `pro-emacs-base-start` | (in `site-init.el`) | Loads every module in the manifest |

`early-init.el` does the things that have to happen **before** any package
loads: `package-enable-at-startup = nil`, load-path setup, GUI hygiene,
best-effort `treesit` require. The `pro-ui-theme.el` is loaded here too,
so the theme is in place before the first frame paints.

## The soft-reload contract

`M-x pro/reload-config` (C-x M-c) re-evaluates every loaded module
**in place**. With `C-u`, it re-evals `site-init.el` first, so a freshly
edited manifest or `provided-packages.el` takes effect.

Modules that own persistent state (child frames, background processes,
cached values) must register teardown on `pro--after-reload-hook`. The
canonical example is `pro-buffer-banner.el`:

```elisp
(when (fboundp 'pro/after-reload)
  (pro/after-reload #'pro-buffer-banner--reload-reset))
```

The reset function destroys the persistent banner frame and the backing
buffer; the next `pro-buffer-banner--show` rebuilds them with the freshly
loaded code's geometry math.

## The visual identity

* **Theme** — `tao-yang` (light, default) or `tao-yin` (dark). Set via
  `pro-ui-default-theme`.
* **Code font** — `Aporetic Sans Mono` 13pt. Set via
  `pro-ui-code-font-family`, `pro-ui-font-height`.
* **Text font** — `Aporetic Sans`. Set via `pro-ui-text-font-family`.
* **Cursor** — orange `#ff8800` for Russian input, green `#0d7a32` for
  English, grey `#808080` for read-only buffers. Configurable via
  `pro-ui-cursor-{russian,english,readonly}-color`.
* **Modeline** — `shaoline` (minimalist). Configurable via
  `pro-ui-modeline-style`.
* **Buffer banner** — child-frame at the top of the selected window,
  shows buffer name + project + branch, theme-aware inverted colors,
  3-second fade-out. See [Reference → defcustom → pro-buffer-banner](reference/defcustom.md).

## The completion stack

* **Vertico** (minibuffer, GUI + TTY) — flat list, cycle, no popup.
* **Corfu** (in-buffer, GUI + TTY) — child frame or in-buffer popup.
  `corfu-auto = t`, `corfu-auto-prefix = 3`, `corfu-auto-delay = 0.25`.
* **Cape** (CAPF backends) — `cape-file`, `cape-keyword`,
  `cape-dabbrev` (on `prog-mode-hook`), `cape-symbol`, `cape-history`,
  `cape-abbrev`, `cape-line`, `cape-dict`. Bound to `C-c o {f, d, h, k, s, a, .}`.
* **Orderless** — fuzzy, used in `command` and `symbol` categories.
* **Consult** — `consult-line`, `consult-buffer`, `consult-ripgrep`,
  `consult-find`, `consult-imenu`, `consult-yasnippet`, `consult-eglot-symbols`.

The minibuffer gets `vertico`. The buffer gets `corfu`. They do not
collide because `pro-completion--maybe-enable-corfu-in-minibuffer` turns
off `corfu-mode` and `corfu-auto` when `vertico--input` or `mct--active`
is bound.

## Where the global keys live

`emacs-keys.org` is the source. `emacs-keys.org` is **executable** — each
row becomes a real `global-set-key` at startup. See
[Reference → Keys](reference/keys.md) for the full table.

Per-user overrides go in `~/.config/emacs/keys.org` (same org-table
format). If both exist, both are parsed in order; user wins on conflict.
