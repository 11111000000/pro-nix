### Adding Keybindings

To add keybindings:
1. Edit `emacs-keys.org` in org-mode.
2. Use `org-babel-execute:org` to compile to Emacs Lisp.
3. For overrides, edit `~/.emacs.d/keys.org` with `:org` prefix.
4. Run `just install-emacs` to apply changes.

Rules:
- `emacs-keys.org` is the source of truth for shared keybindings.
- `~/.emacs.d/keys.org` is for user overrides only.
- Keep changes checkable in text.

Emacs Lisp rules:
- Keep functions small and explicit.
- Prefer one file per concern.
- Make load order explicit when it matters.
- Treat text as the contract when the config is generated.

Keybindings are automatically loaded from `~/.emacs.d/keys.el`.
