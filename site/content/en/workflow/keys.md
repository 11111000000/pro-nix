+++
title = "Keys"
template = "page.html"
weight = 5

[extra]
tldr = "emacs-keys.org is executable. pro-keys-reload parses it, applies global keys, defers pending bindings until the target package loads. User override: ~/.config/emacs/keys.org. Modules propose via pro/register-module-keys."

[[extra.next]]
title = "Soft-reload"
url = "/workflow/reload/"

[[extra.next]]
title = "Tests"
url = "/workflow/tests/"
+++

# Keys

`emacs-keys.org` is the **executable source of truth** for global
key bindings. It is **not** documentation. Each row in the org-table
becomes a real `global-set-key` at Emacs startup. Modules propose
new bindings through `pro/register-module-keys`; user overrides go
in `~/.config/emacs/keys.org`.

## The format

The file is an org-mode table. The first column is the **section
name** (used to group bindings in the right keymap), the second is
the **key**, the third is the **command**, the fourth is the
**human-readable description**.

| Секция | Клавиша | Команда | Описание |
|--------|---------|---------|----------|
| Поиск | C-s | isearch-forward | Обычный isearch |
| UI | C-= | pro-ui-zoom-in | Увеличить шрифт |
| EXWM | s-r | exwm-reset | Сброс окна EXWM |

The parser (`emacs/base/modules/pro-keys.el`) dispatches on the
section name:

* `UI` / `EXWM` → `global-set-key` (always available).
* `ORG` → `org-mode-map` (only when an `org-mode` buffer is active).
* `Snippets` / `LSP` / `Completion` → `with-eval-after-load` after the
  corresponding feature is loaded.
* `Suggested` → `pro-keys-pending-bindings` (applied once the
  command's package becomes available).

See [Reference → Keys](reference/keys.md) for the full table.

## How `pro-keys-reload` works

`pro-keys-reload` (interactive, no prefix args):

1. Parse `emacs-keys.org` (and `~/.config/emacs/keys.org` if it
   exists) as org-tables.
2. For each row, dispatch to the right keymap.
3. Store any binding whose target command is not yet defined in
   `pro-keys-pending-bindings`.
4. After parsing, run `pro-keys-apply-pending` to retry the stored
   bindings.
5. Print a summary: "X bindings applied, Y pending."

The function is **idempotent** — it can be called as many times as
you want, and the result is the same set of bindings.

## Pending bindings

Some bindings reference commands from packages that may not be
loaded at the time the table is parsed (e.g. `magit-status` from
`magit`). For these, `pro-keys.el` stores the binding in
`pro-keys-pending-bindings` and registers an `autoload` retry:

```elisp
(when (fboundp 'magit-status)
    (define-key global-map (kbd "C-x g") #'magit-status)
  (autoload #'magit-status "magit" nil t)
  (add-hook 'after-load-functions
            (lambda (_)
              (when (fboundp 'magit-status)
                (define-key global-map (kbd "C-x g") #'magit-status)))))
```

`M-x pro-keys-report-pending` prints the list of pending bindings
so the user can `M-x package-install` the missing packages if
needed.

## How modules propose bindings

Modules call `pro/register-module-keys` to **suggest** a binding. The
suggestion is stored in `pro/registered-module-keys` and merged
into the `emacs-keys.org` table by the
`pro/keys-import-suggestions` command.

```elisp
(pro/register-module-keys
 "C-c a" 'pro-ai-open-entry "AI entry")
```

After the module is loaded, the user runs `M-x pro/keys-import-suggestions`,
which adds a row to `emacs-keys.org` with the binding in the
`Suggested` section. The user can then promote it to the right
section (e.g. `AI`) by editing the org-table directly.

This is the **canonical workflow** for adding a binding: the module
suggests, the user curates. No module directly calls
`global-set-key` (the lint in `helper-lint-keys.sh` enforces this).

## User overrides

A user can override the system table by writing
`~/.config/emacs/keys.org` in the **same** org-table format. The
parser reads both files; if a key is bound in both, the **user**
version wins (last-writer-wins, user is parsed second).

A typical user override:

```org
#+title: User keys

| Section   | Key         | Command               | Note                       |
|-----------+-------------+-----------------------+----------------------------|
| UI        | C-x M-c     | pro/reload-config     | Reload Emacs config        |
| User      | C-c u       | my-org-capture-tmpl   | Custom capture template    |
```

The `User` section name is conventional — the parser does not
care about the section name, only the columns.

## The `pro-keys-apply-pending` hook

After every soft-reload (`M-x pro/reload-config`), `pro-keys-reload`
is called. This re-parses both files and re-applies all bindings.
The pending-bindings mechanism is also re-triggered: any binding
whose target command was not yet available is retried.

This means: **edit `emacs-keys.org`, save, `M-x pro-keys-reload`
(or C-c k)**, and the new binding is live. No Emacs restart.

## The `pro/keys-import-suggestions` workflow

If you add a binding to a module via
`(pro/register-module-keys ...)` and want to merge it into
`emacs-keys.org`:

```elisp
M-x pro/keys-import-suggestions
```

This:

1. Reads `pro/registered-module-keys` (all suggestions from
   loaded modules).
2. Appends a new section `Suggested` to `emacs-keys.org` with
   one row per unregistered suggestion.
3. Clears `pro/registered-module-keys` so the same suggestion is
   not added twice.

The user then promotes the row to the right section by editing
the org-table.

## The `Suggested` section convention

`emacs-keys.org` has a `Suggested` section at the bottom. New
proposals from modules go there until the user curates them. The
section is parsed but the keys are applied to `global-map` (since
the section is not one of the dispatched names like `UI` / `EXWM`).

## Section → keymap dispatch

| Section | Applied to |
|---------|------------|
| `UI`, `EXWM` | `global-map` |
| `ORG` | `org-mode-map` (in `with-eval-after-load 'org`) |
| `Snippets`, `LSP`, `Completion` | `with-eval-after-load` for the relevant feature |
| `History` | `global-map` (the `pro-history-*` commands) |
| `Docker` | `global-map` (the `pro-docker-*` commands) |
| `AI`, `Чат`, `Tabs`, `Package`, `Git`, `Org`, `Ключи`, `Haskell`, `Profiler` | `global-map` |
| `Suggested` | `global-map` (the user is expected to promote) |

The dispatch is in `pro-keys.el:pro-keys--dispatch-section`. The
`Suggested` section is special — it is the only one whose
bindings are applied even before user curation, so a fresh
module's `pro/register-module-keys` calls work out of the box.

## Lint: no `global-set-key` in modules

`scripts/helper-lint-keys.sh` enforces the convention:

```bash
rg -n "\bglobal-set-key\s*\(" --glob "**/*.el" \
   | rg -v '/keys\.el:'
```

The `rg -v` excludes `pro-keys.el` itself (the only file that
should call `global-set-key`). Any other file that does is a
violation.

## Adding a binding to an existing module

```elisp
;; In your pro-foo.el
(pro/register-module-keys
 "C-c f x" 'pro-foo-do-thing "Do the foo thing")
```

Then `M-x pro/keys-import-suggestions` to add the row to
`emacs-keys.org`. Edit the row's section if you want it in `UI`
instead of `Suggested`. Save the file. `M-x pro-keys-reload`. The
binding is live.

## Adding a new module-level key

Same workflow. The module does not call `global-set-key`
directly. The `pro/register-module-keys` form is the
**proposal**, and `emacs-keys.org` is the **canonical** location.

If a module tries to bind a key directly (e.g. via
`define-key some-mode-map`), the lint will catch it only if it
calls `global-set-key`. The convention is to put the binding in
`emacs-keys.org` so it shows up in the auto-generated
[Reference → Keys](reference/keys.md) page.
