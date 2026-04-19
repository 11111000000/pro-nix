## HDS Rules

1. Surface first: record user-visible contract here before changing implementation.
2. Text is test: if a rule matters, write it in text and keep a check for it.
3. One file, one concern: keep modules small and single-purpose.
4. Prefer explicit loading order over hidden coupling.
5. Use Org as the source of truth for keybindings and other declarative surfaces.

## Emacs Lisp Style

1. Keep functions small and named by role, not by mechanism.
2. Prefer explicit contracts over clever control flow.
3. Use `use-package` for external packages and plain `defun`/`setq` for local policy.
4. Avoid hidden dependencies between modules; declare load order when it matters.
5. When a rule must survive LLM generation, write it as text and make it checkable.

## Keybinding Interface

1. Define keybindings in `emacs-keys.org` (org-mode).
2. Compile to Emacs Lisp with `org-babel-execute:org`.
3. Put overrides in `~/.emacs.d/keys.org` with the `:org` prefix.
4. Apply changes with `just install-emacs`.

> Keybindings compile to `~/.emacs.d/keys.el` and load automatically.
