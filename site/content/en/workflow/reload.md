+++
title = "Soft-reload"
template = "page.html"
weight = 6

[extra]
tldr = "C-x M-c (pro/reload-config) re-evaluates every loaded module in place. C-u re-evals site-init.el first. Modules owning persistent state register on pro--after-reload-hook. Idempotent top-level forms via pro-compat--add-{hook,to-list,advice}-once."

[[extra.next]]
title = "Tests"
url = "/workflow/tests/"

[[extra.next]]
title = "Per-host checklist"
url = "/workflow/per-host/"
+++

# Soft-reload

`M-x pro/reload-config` (**C-x M-c**) re-evaluates every loaded
module **in place**. It is the second-most-frequent command in
the project (after `M-x`).

## What it does

```elisp
(defun pro/reload-config (&optional full)
  "Reload the whole pro Emacs configuration to apply changes
without restarting.

If FULL is non-nil (or called with a prefix argument), re-eval
site-init.el from disk (which re-runs provided-packages loading
and the top-level init) AND re-load every module. The non-full
path re-evaluates each module's .el file in place.

Both paths run pro--before-reload-hook (modules can tear down
child frames / bg processes / cached state) and
pro--after-reload-hook (modules re-create persistent state
from the freshly loaded code)."
  (interactive "P")
  ...)
```

The full sequence (non-full path):

1. Refresh Nix-generated paths (if the script is available).
2. `run-hooks 'pro--before-reload-hook` — modules tear down.
3. `pro/reload-all-modules` — drop each module from
   `load-history`, then `load-file` it. The `pro--forget-file-in-load-history`
   helper removes the matching entry from `load-history` and
   `unload-feature`'s the provided feature.
4. `pro-keys-reload` + `pro-keys-apply-pending` + `pro-keys-report-pending`
   — re-apply global keys.
5. `pro--reconstruct` (if `pro-epistemology.el` is loaded) —
   reconstruct the epistemic state from a saved snapshot.
6. Re-apply UI tweaks: fonts, fringes, completion, icons, modeline,
   theme.
7. `run-hooks 'pro--after-reload-hook` — modules re-create
   persistent state.
8. Print the time taken.

The full path adds step 3.5: re-eval `site-init.el` first. This is
useful when the manifest or `provided-packages.el` has changed.

## Why `pro--forget-file-in-load-history`

Emacs uses `load-history` as the source of truth for whether a
file is "loaded" and "up to date". If a file's mtime matches
the recorded load time, `load` silently skips re-evaluation —
even when the user explicitly asks for a reload.

```elisp
(defun pro--forget-file-in-load-history (file)
  "Remove all load-history entries whose file is FILE (or its .elc).
Also unbind features provided by the file."
  ...)
```

This helper:

1. Walks `load-history` and removes entries whose `car` is
   `file` (or its `file-truename`, or its `.elc`).
2. Collects the `provide`d features from those entries.
3. `unload-feature` each one, so the next `provide` is the
   "real" one.
4. Removes the matching `.elc` from `load-history` too (so the
   fresh `.el` wins over a stale `.elc`).

After this, the next `load-file file` re-evaluates the file from
scratch.

## The module-author contract

From the file header of `pro-reload.el`:

> Reload contract for module authors:
>
> * Re-evaluating a module via `pro/reload-module` always runs the
>   *current* contents of the .el file (we drop the load-history
>   entry, so mtime tricks with .elc don't mask changes).
> * Modules that own persistent state (child frames, background
>   processes, globalised variables) should register a teardown
>   function on `pro--after-reload-hook` so a reload actually
>   re-creates that state from the freshly-loaded code. Use
>   `pro/after-reload #'my-reset-fn`.
> * Modules should keep their top-level forms idempotent (use the
>   `pro-compat--add-hook-once` / `add-to-list-once` /
>   `advice-add-once` helpers) — re-evaluation will re-run them
>   on every reload.

Three rules. The first is enforced by `pro--forget-file-in-load-history`
— you do not have to do anything. The second is **your** job. The
third is enforced by the `pro-compat` helpers.

## The `pro-compat` helpers

```elisp
(pro-compat--add-hook-once       'some-hook  #'some-function)
(pro-compat--add-to-list-once    'some-list  'some-symbol)
(pro-compat--advice-add-once     'some-fn :before #'some-wrapper)
```

Each is a thin wrapper that checks `memq` (for hooks), `member` (for
lists), or `advice-member-p` (for advice) before adding. This
makes top-level forms safe to re-evaluate.

Without these helpers, a soft reload would add the same hook
twice, add the same list element twice, or double-wrap advice.
The result: subtle bugs (e.g. a function runs twice after every
reload) that only manifest on the second or third reload.

## The teardown pattern

For a module that creates a child frame on load:

```elisp
(defun pro-mine--reset ()
  "Teardown for pro-mine. Called on pro--after-reload-hook."
  (when (frame-live-p pro-mine--frame)
    (delete-frame pro-mine--frame))
  (setq pro-mine--frame nil
        pro-mine--cache nil))

(when (fboundp 'pro/after-reload)
  (pro/after-reload #'pro-mine--reset))
```

The reset function:

1. Checks that the frame is still alive.
2. Deletes it.
3. Resets the module-level cache variables.
4. The next time the module's "show" function runs (after the
   reload, the user does whatever triggers it), the frame is
   re-created with the freshly loaded code's geometry.

The canonical example is `pro-buffer-banner.el`. The reload-reset
function is at `emacs/base/modules/pro-buffer-banner.el:737-760`.

## Soft reload vs hard restart

| | Soft reload (C-x M-c) | Hard restart |
|---|------------------------|---------------|
| Speed | < 1 s | 5-10 s |
| State | Frame layouts, terminal buffers, magit, … survive | Everything lost |
| Persistent module state | Reset by `pro--after-reload-hook` | All gone |
| Web-mode, LSP servers | Stay up (they are external processes) | Need to restart |
| `provided-packages.el` change | Not picked up — use `C-u` to re-eval `site-init` | Picked up |
| Manifest change | Not picked up — use `C-u` | Picked up |
| Bug in a module | Reload may surface it as a clear error in `*Messages*` | May hang on startup |

The general rule: use soft reload for "I edited a function and
want to test it". Use hard restart for "I edited the manifest or
`provided-packages.el`" or "soft reload misbehaves".

## The `pro/session-save-and-restart-emacs` escape hatch

For the rare case where soft reload is not enough but you do not
want to lose your session:

```elisp
M-x pro/session-save-and-restart-emacs
```

This:

1. Calls `pro/session-save` to write `~/.emacs.d/.pro-session.el`
   (open files + point + window state).
2. Starts a new Emacs subprocess that loads the saved session.
3. Kills the current Emacs.

Result: a fresh Emacs with all the files and window state you had
before.

## Soft-reload the whole site

If you edit `emacs/base/modules/pro-reload.el` itself, a soft
reload will not pick up the change (the module that is performing
the reload cannot reload itself). You need to:

* `M-x pro/reload-module pro-reload` — reloads just this module.
* `C-u M-x pro/reload-config` — full reload (re-evals `site-init`
  + all modules).
* Restart Emacs — last resort.

## Common pitfalls

| Symptom | Cause | Fix |
|---------|-------|-----|
| "Module not owned by current user" on every reload | sudo-activation wrote files as root | `sudo chown -R $USER ~/.config/emacs` (helper-switch.sh does this) |
| Reload seems to do nothing | mtime trick — `load-history` thinks the file is up to date | Check that the `pro--forget-file-in-load-history` helper ran (it should, by default) |
| Frame survives reload but is in a wrong position | Module does not have a reset function on `pro--after-reload-hook` | Add one (see the teardown pattern above) |
| A function is called twice after reload | Module's top-level form is not idempotent | Wrap with `pro-compat--add-{hook,to-list,advice}-once` |
| Reload errors with "Cannot open load file" | A module was deleted but the manifest still references it | Remove from `pro-emacs-base-default-modules` in `site-init.el` |
