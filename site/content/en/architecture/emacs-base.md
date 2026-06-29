+++
title = "Emacs bootstrap"
template = "page.html"
weight = 4

[extra]
tldr = "Four phases: early-init → init → site-init (manifest + resolver) → pro-emacs-base-start. Soft-reload contract lets modules own persistent state. provided-packages.el comes from Nix."

[[extra.next]]
title = "AI agent stack"
url = "/architecture/agents/"

[[extra.next]]
title = "Reference defcustom"
url = "/reference/defcustom/"
+++

# Emacs bootstrap

The Emacs side has its own four-phase bootstrap, intentionally decoupled
from the Nix system. You can use the same `emacs/base/` from a non-NixOS
host — `pro-nix-emacs-sync.sh` does exactly that.

## Phase 1: `early-init.el`

`emacs/base/early-init.el` runs **before** `package.el` activates. It
sets:

* `package-enable-at-startup = nil` — never auto-install on first start.
* `package-quickstart-file` — points at `~/.config/emacs/quickstart.el`
  (in `user-emacs-directory`).
* `package-quickstart-sync = nil` — do not rewrite the quickstart file.
* `frame-inhibit-implied-resize = t` — no flicker on first frame.
* `inhibit-splash-screen = t`.

It also adds the `modules/` directory to `load-path` (computed relative
to the file) so a `require 'pro-foo` in `init.el` works even if
`init.el` itself is loaded from `/nix/store/...`.

Best-effort: `(require 'treesit nil t)` so tree-sitter symbols are
available to native-compilation of third-party packages.

In GUI frames: disable fringes, set the window-divider. Then load
`pro-ui-theme` so the theme is in place before the first frame paints.

## Phase 2: `init.el`

`emacs/base/init.el` is the main loader. It does:

1. Set `user-emacs-directory` to `~/.config/emacs/`.
2. Set `custom-file` to `~/.config/emacs/custom.el` (so user customizations
   survive `nixos-rebuild switch`).
3. `load custom.el` if it exists.
4. `setq pro-emacs-base-system-modules-dir` to the repo's `modules/`
   directory.
5. `load pro-compat` and `pro-packages` early so any later module can
   consult them.
6. Configure MELPA / ELPA archives via `pro-packages-configure-archives`.
7. `pro-packages-initialize` to make the package system ready.
8. `package-install-upgrade-built-in = t` — allow upgrading `transient`,
   which ships with Emacs but is too old for `magit`.
9. Add `modules/` to `load-path`.
10. `load site-init.el`.
11. `pro-emacs-maybe-bootstrap-on-first-start` — marker-based, no network
    on subsequent starts.
12. `pro-emacs-base-start` — the actual module loader.

The final `provide 'pro-init` is for tests / introspection.

## Phase 3: `site-init.el`

`emacs/base/site-init.el` is the **module manifest and resolver**. Its
job is to read the manifest, find each module's file (with
user-override preference), and load it.

### The manifest

```elisp
(defvar pro-emacs-base-default-modules
    '(pro-core pro-ui pro-packages pro-package-bootstrap pro-project pro-git
      pro-nix pro-js pro-ai pro-agent-shell pro-emcp pro-c pro-chat pro-telega pro-compat
      pro-completion pro-completion-keys pro-consult-helpers pro-dired
      pro-app-launcher pro-clipboard
      pro-emacs-check-fonts pro-exwm-sim pro-exwm pro-feeds pro-fix-corfu
      pro-haskell pro-java pro-key-utils pro-keys pro-lisp pro-markdown pro-nix-refresh
      pro-org pro-python pro-reload pro-session pro-history pro-spell pro-startup-metrics pro-profiler pro-tabs
      pro-terminals pro-test-helpers pro-tests pro-tests-keys pro-text
      pro-ui-completion pro-ui-fonts pro-ui-fringes pro-ui-icons
      pro-ui-improvements pro-buffer-banner pro-ui-modeline pro-ui-theme pro-ui-tty
      pro-dashboard pro-help pro-windows-popups
      pro-vterm-theme pro-windows pro-nav pro-docker)
  "Полный список модулей, загружаемых по умолчанию при старте Emacs.")
```

A user can override this by setting `pro-emacs-modules` (or
`my-emacs-modules`, or `pro-emacs-base-modules`) in
`~/.config/emacs/modules.el`. See
`templates/decisions.el.example`-style snippets.

### The resolver

`pro-emacs-base--resolve-module` looks in two places:

1. `~/.config/emacs/modules/<name>.el` (HM-deployed, user override).
2. `pro-emacs-base-system-modules-dir/<name>.el` (the repo's modules).

The user-override wins **only if the file is owned by the current
user**. This is the protection against root-owned HM files breaking
Emacs:

```elisp
(user-owner-ok (or user-dir-symlink
                 user-file-symlink
                 (and user-attrs
                      (= (nth 2 user-attrs) (user-uid)))))
```

If the user file is **not** owned by the current user, the resolver
prefers the system module and logs a `[pro-emacs]` message. This is
why `helper-switch.sh` does `chown -R $USER ~/.config/emacs` after
`nixos-rebuild switch`.

### Loading

`pro-emacs-base-start`:

```elisp
(dolist (module pro-emacs-base-default-modules)
  (let ((resolved-file (pro-emacs-base--resolve-module module)))
    (if resolved-file
        (condition-case err
            (load resolved-file nil t)
          (error (message "[pro-emacs] failed to load %s: %S" resolved-file err)))
      (message "[pro-emacs] missing module: %s" module))))
```

Idempotent: every module's top-level forms are guarded with
`pro-compat--add-hook-once` and similar, so a re-evaluation does not
re-install hooks, re-add to lists, or re-apply advice.

### `provided-packages.el`

`site-init.el` first tries to load `~/.config/emacs/provided-packages.el`
(the HM-deployed file). If that file is missing **or** not user-writable
(a sign that HM owns it), it falls back to the repo's copy at
`emacs/base/provided-packages.el`.

The file content is `(setq pro-packages-provided-by-nix '(magit vertico
consult …))` — the same 60+ names that appear in
`emacs/core.nix#pro.emacs.providedPackages`.

`pro-packages.el` consults `pro-packages-provided-by-nix` to decide
"is this package Nix-provided, or do I need to install it from MELPA?".

### Pending bindings

After loading all modules, `site-init.el` calls
`pro-keys-apply-pending` and `pro-keys-report-pending`. The first
re-applies any global keys that were deferred because their target
package was not yet loaded; the second prints a summary of pending
bindings so the user can `M-x package-install` them if needed.

## Phase 4: `pro-emacs-base-start`

This is where the actual work happens. It is the `pro-emacs-base-start`
function called from `init.el:50`. It iterates the manifest, resolves
each module, and loads it. The function is **idempotent**: you can call
it twice and the second call is a no-op (because `provide` is guarded
by `(featurep 'pro-foo)` and the top-level forms are guarded).

After all modules load, `pro-keys-apply-pending` and
`pro-keys-report-pending` are called. Then `pro--reconstruct` (if
provided by `pro-epistemology.el`) reconstructs the epistemic state
from a saved snapshot — this is the "save my thoughts across reloads"
feature.

## The soft-reload contract

`emacs/base/modules/pro-reload.el` defines:

```elisp
(defvar pro--before-reload-hook nil)
(defvar pro--after-reload-hook  nil)

(defun pro/before-reload (fn) ...)
(defun pro/after-reload  (fn) ...)
(defun pro--forget-file-in-load-history (file) ...)
(defun pro/reload-module (module) ...)
(defun pro/reload-all-modules () ...)
(defun pro/reload-config (&optional full) ...)
```

`pro--forget-file-in-load-history` removes the file from
`load-history` and `unload-feature`'s the provided feature, so the next
`load` actually re-evaluates the file (without this, Emacs sees the
matching mtime and silently skips).

`pro/reload-config`:

1. Refresh Nix-generated paths (if the script is available).
2. `run-hooks 'pro--before-reload-hook` (modules tear down child frames,
   bg processes, cached state).
3. If `full`, re-eval `site-init.el` (so the manifest and
   `provided-packages.el` pick up changes); then `pro/reload-all-modules`.
   Otherwise, just `pro/reload-all-modules`.
4. Re-apply key bindings, fonts, fringes, completion, icons, modeline,
   theme.
5. `run-hooks 'pro--after-reload-hook` (modules re-create persistent
   state from the freshly loaded code).
6. Print a summary message with the time taken.

### Module-author checklist

From the file header of `pro-reload.el`:

> Reload contract for module authors:
>
> * Re-evaluating a module via `pro/reload-module` always runs the
>   *current* contents of the .el file (we drop the load-history entry,
>   so mtime tricks with .elc don't mask changes).
> * Modules that own persistent state (child frames, background
>   processes, globalised variables) should register a teardown
>   function on `pro--after-reload-hook` so a reload actually
>   re-creates that state from the freshly-loaded code. Use
>   `pro/after-reload #'my-reset-fn`.
> * Modules should keep their top-level forms idempotent (use the
>   `pro-compat--add-hook-once` / `add-to-list-once` / `advice-add-once`
>   helpers) — re-evaluation will re-run them on every reload.

## The manifest is data

Because `pro-emacs-base-default-modules` is a `defvar` (not a
`defconst`), the user can override it from
`~/.config/emacs/modules.el` at load time. This is the *only* way to
customize the manifest — there is no per-host NixOS option for it.

`templates/decisions.el.example` is a starting point:

```elisp
(setq pro-emacs-modules
      '(pro-core pro-ui pro-...))
```

`site-init.el` reads this file first (`load-file
pro-emacs-base-user-manifest`), then falls back to
`pro-emacs-base-default-modules`.

## The `~/.config/emacs/decisions.el` file

Decisions are per-package overrides, not per-module:

```elisp
(setq pro-packages-decisions
      '((gptel . always)        ; always install from MELPA, even if Nix provides it
        (magit . always)
        (somepkg . never)))     ; never install, even if requested
```

`pro-packages.el` checks `pro-packages-decisions` before
auto-installing a missing package. This lets the user opt out of
specific packages without removing the module that pulls them in.
