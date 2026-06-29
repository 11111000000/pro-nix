+++
title = "AI agents layer"
template = "page.html"
weight = 3

[extra]
tldr = "pi + opencode + EMCP + gptel. MCP servers: emcp (Emacs) and chrome-devtools. Skills: emacs-emcp, safe-bash. Permission system: deny-by-pattern."

[[extra.next]]
title = "Window managers"
url = "/stack/wm/"

[[extra.next]]
title = "AI agent stack"
url = "/architecture/agents/"
+++

# AI agents layer

The agent layer is **Nix-installed for the binaries, template-deployed
for the configs, runtime-configured for the keys**. None of the three
agents store secrets on disk; they read `~/.authinfo` (or
`~/.authinfo.gpg`) through `~/.local/share/pro-nix/load-agent-env.sh`,
sourced from `~/.profile`.

## The three agents

### `pi` (lukasl-dev/pi.nix)

The primary CLI. The NixOS module (`pi.nixosModules.default`) is wired
in globally in `configuration.nix`:

```nix
programs.pi.coding-agent = lib.mkIf (piPkg != null) {
  enable = lib.mkDefault true;
  package = lib.mkDefault piPkg;
  rules = lib.mkDefault "";
};
```

`pi` is launched through `pi-acp` (`svkozak/pi-acp` v0.0.27, built by
`nix/node-packages/pi-acp.nix`) for ACP communication. The full settings
live in `local-templates/pi/settings.json`:

```json
{
  "defaultProvider": "minimax",
  "defaultModel": "MiniMax-M3",
  "packages": [
    "npm:pi-mcp-adapter", "npm:pi-smart-fetch", "npm:pi-web-access",
    "npm:@spences10/pi-redact", "npm:@spences10/pi-recall",
    "npm:@gotgenes/pi-permission-system", "npm:pi-compass", "npm:pi-blueprint"
  ]
}
```

`pi-crew` and `pi-subagents` are **deliberately excluded** — see
`local-templates/pi/settings.json` for the list of unsupported
multi-agent packages.

### `opencode`

The second agent. An npm binary (`v1.15.10`), downloaded by
`nix/overlays/opencode-stub.nix` and `patchelf`'d to the NixOS glibc.
The bwrap'd variant is wired through `opencodeBwrap.homeManagerModules.default`
(Home Manager module from `michalrus/opencode-bwrap-nix`).

Config in `local-templates/opencode/opencode.json` — same four
providers as `pi`, same MCP servers.

### `gptel` (Emacs-side LLM client)

`emacs/base/modules/pro-ai.el` is the policy layer on top of gptel:

* 4 providers from `emacs/base/modules/ai-models.json` (openrouter, siliconflow, aitunnel, plus user overrides).
* `pro-ai-backend` (default `'aitunnel`) chooses the active one.
* `pro-ai-open-entry` (C-c a) opens a gptel transient; user picks model.
* Carriage integration (`gnu-emacs-ru/carriage`): Org-mode "code knitting"
  workflow with dry-run/apply and reproducibility.

## MCP — the bridge to Emacs

EMCP (Emacs MCP) is the headline integration. It exposes the running
Emacs session as an MCP server, so any MCP-capable agent can read buffers,
eval elisp, take screenshots, send keys.

| Server | Where it runs | What it does |
|--------|---------------|--------------|
| `emcp` | Inside Emacs, port 38913 | Read/eval/send-keys/screenshot on the live session |
| `chrome-devtools` | `npx chrome-devtools-mcp@latest` (when running) | Browser automation through Chrome DevTools Protocol |

Both are registered in **both** `local-templates/pi/mcp.json` and
`local-templates/opencode/opencode.json`.

### How `pi` calls emcp

`pi` routes MCP through a **proxy tool**:

```
pi> mcp({tool: "emcp_apropos", args: {pattern: "pro-"}})
```

This is the **only** way `pi` reaches an MCP tool — there is no direct
`emcp_apropos` tool in `pi`.

### How `opencode` calls emcp

`opencode` exposes MCP tools directly:

```
opencode> emcp_apropos(pattern: "pro-")
```

The MCP `tools/list` returns the full emcp toolset.

### The `eval` / `send-keys` policy gate

Two emcp tools are **dangerous by default** and gated by an Emacs-side
policy:

* `emcp_eval` — runs arbitrary elisp in the user's session.
* `emcp_send_keys` — sends a key sequence to the user's session.

`emcp-tools-eval-default-policy` and `emcp-tools-send-keys-default-policy`
default to `'ask`. When the agent calls one of these, Emacs opens a
`*EMCP confirm*` buffer with `y` / `n` / `a` (always accept for the
session) / `r` (always reject for the session) / `q` (cancel).

The gate is described in detail in
`local-templates/pi/skills/emacs-emcp/SKILL.md` and
`local-templates/opencode/skills/emacs-emcp/SKILL.md`.

## The permission system

`local-templates/pi/extensions/pi-permission-system/config.json`
configures `@gotgenes/pi-permission-system`. Defaults:

* `path` rules:
  * **deny** `.env*`, `secrets.*`, `*.pem`, `*.key`, `id_rsa*`,
    `id_ed25519*`, `~/.ssh/**`, `~/.aws/**`, `~/.gnupg/**`,
    `~/.pi/agent/auth.json`
  * **ask** `~/.pi/agent/models.json`
* `bash` rules:
  * **deny** `rm -rf *`, `rm -rf /*`, `dd *`, `mkfs*`, fork bomb,
    `chmod 777`, `curl|sh`, `wget|sh`, `git push --force`,
    `nix-collect-garbage -d`, `kill -9 1`, `reboot`, `shutdown`
  * **ask** `sudo *`, `chown *`, `git push *`, `nix-env *`, `systemctl *`
* `mcp`: `*` = allow
* `skill`: `*` = ask
* `external_directory`: ask

`yoloMode = false`, `debugLog = false`, `permissionReviewLog = true`.

## Skills

Two skills are deployed to both `~/.pi/agent/skills/` and
`~/.config/opencode/skills/`:

| Skill | File | Purpose |
|-------|------|---------|
| `emacs-emcp` | `local-templates/{pi,opencode}/skills/emacs-emcp/SKILL.md` | Operator guide for the emcp MCP server. Lists the tools, the policy gate, the `full-control` profile, and the troubleshooting steps. |
| `safe-bash` | `local-templates/pi/skills/safe-bash/SKILL.md` | Cross-platform shell safety. Read-only vs mutating classification, destructive confirmation patterns, Windows/Unix path conventions, signal handling, anti-patterns. |

## The local-templates ↔ $HOME deployment

`modules/pro-agent-configs.nix` defines 6 file copies:

```
local-templates/opencode/opencode.json        → ~/.config/opencode/opencode.json
local-templates/opencode/skills/...          → ~/.config/opencode/skills/...
local-templates/pi/models.json               → ~/.pi/agent/models.json
local-templates/pi/mcp.json                  → ~/.pi/agent/mcp.json
local-templates/pi/settings.json             → ~/.pi/agent/settings.json
local-templates/pi/skills/...                → ~/.pi/agent/skills/...
```

The activation script uses `install -m 0644 -o $(id -u) -g $(id -g)` to
avoid the "files owned by root after sudo-activation" problem. It is
**copy-if-missing** — never overwrites user edits.

A marker comment is appended to `~/.profile`:

```
# pro-nix: load AI provider keys from authinfo
[ -f "$HOME/.local/share/pro-nix/load-agent-env.sh" ] && . "$HOME/.local/share/pro-nix/load-agent-env.sh"
```

The marker is idempotent — it is only appended if the marker is not
already present.

## The `just` surface

```bash
just deploy-agents            # copy local-templates to $HOME
just install-pi-packages      # pi install npm:<pkg> for every package in settings.json
just switch-with-agents <host>   # chain: deploy + install + switch
just update-pi-version       # bump pi in flake.lock (dry-run by default)
```

`deploy-agents.sh` is the manual equivalent of the Nix activation. Use
it on a non-NixOS host, or when you want to force a deploy.
