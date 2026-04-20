### Adding Keybindings

To add keybindings:
1. Edit `emacs-keys.org` in org-mode.
2. Use `org-babel-execute:org` to compile to Emacs Lisp.
3. For overrides, edit `~/.emacs.d/keys.org` with `:org` prefix.
4. Run `just install-emacs` to apply changes.

### Agent Tools

The system profile now exposes these agent commands on PATH:

- `goose`
- `aider`
- `opencode`
- `agent-shell` in Emacs

In Emacs, `C-c a` opens the main AI buffer and `C-c A` opens `agent-shell`.

See `docs/agents.md` and `docs/plans/agent-tooling.md` for setup and policy.

Rules:
- `emacs-keys.org` is the source of truth for shared keybindings.
- `~/.emacs.d/keys.org` is for user overrides only.
- Keep changes checkable in text.

Optional heavy packages (browsers, messaging, HLS, etc.) are disabled by default to keep builds small. See `docs/optional-packages.md` to enable them per-host or via Home Manager.

Emacs Lisp rules:
- Keep functions small and explicit.
- Prefer one file per concern.
- Make load order explicit when it matters.
- Treat text as the contract when the config is generated.

Keybindings are automatically loaded from `~/.emacs.d/keys.el`.
