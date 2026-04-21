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

Quick start (high level)

1. Clone the repository and review `SURFACE.md` to understand the public contract.
2. For NixOS hosts: apply the configuration for a host (example `cf19`):
   `sudo nixos-rebuild switch --flake .#cf19` (or `su -` then `nixos-rebuild switch --flake .#cf19`).
3. If `pro-peer` mode is used, operator must place `/etc/pro-peer/authorized_keys.gpg` on the host
   (see `docs/plans/pro-peer-hardening-plan.md`); `pro-peer-sync-keys.service` will decrypt it.
4. For Emacs development: run `just install-emacs` to compile keybindings and install packages.

Notes about compatibility and safety

- The repo supports a range of NixOS versions. Some options (eg. `networking.nftables`) are
  not available on older releases — the config contains fallbacks to ensure compatibility.
- Be cautious with Samba exposure: Samba is hardened by default, and SMB ports are restricted to
  RFC1918 networks via firewall rules. See `docs/ops/samba-hardening.md` for details and
  per-host override instructions.
