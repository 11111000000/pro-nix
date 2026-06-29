+++
title = "AI agent stack"
template = "page.html"
weight = 5

[extra]
tldr = "pi + opencode + EMCP + gptel + pi-acp. Five pieces: Nix-installed binaries, deployed templates, MCP servers, skills, permission system. Connected through ~/.authinfo + load-agent-env.sh."

[[extra.next]]
title = "Network layers"
url = "/architecture/network/"

[[extra.next]]
title = "AI agents layer"
url = "/stack/ai/"
+++

# AI agent stack

The agent layer is the **youngest** in the project and the most
frequently changed. It has five parts that compose:

1. **Binaries** — installed by Nix (pi, pi-acp, opencode).
2. **Templates** — source of truth in `local-templates/`, deployed to
   `$HOME` by `pro-agent-configs.nix`.
3. **MCP servers** — `emcp` (Emacs) and `chrome-devtools` (browser).
4. **Skills** — operator guides that the agent loads on demand.
5. **Permission system** — deny-by-pattern defaults that gate dangerous
   operations.

## 1. The binaries

| Binary | Source | How it's built | Where it lands |
|--------|--------|----------------|----------------|
| `pi` | `lukasl-dev/pi.nix` (via `pi.packages.x86_64-linux.coding-agent`) | Upstream Nix package | `/run/current-system/sw/bin/pi` |
| `pi-acp` | `nix/node-packages/pi-acp.nix` (svkozak/pi-acp v0.0.27) | `buildNpmPackage` with Node 20, `npmDepsHash` pinned | `/run/current-system/sw/bin/pi-acp` |
| `opencode` | `nix/overlays/opencode-stub.nix` | `fetchurl` of npm tarball + `patchelf` for glibc | `/run/current-system/sw/bin/opencode` |
| `opencode-bwrap` | `opencodeBwrap.homeManagerModules.default` | HM module wraps `opencode` in a bwrap sandbox | `~/.local/bin/opencode` (per user) |
| `gptel` (in Emacs) | `pkgs.emacsPackages.gptel` | MELPA build | `share/emacs/site-lisp/.../gptel*.el` |
| `emcp` (in Emacs) | `nix/emacs-recipes/emcp.nix` | Trivial `cp` of submodule | `share/emacs/site-lisp/emcp/emcp.el` |
| `http-server` (in Emacs) | `nix/emacs-recipes/http-server.nix` | Trivial `cp` of upstream fork | `share/emacs/site-lisp/http-server/...` |

`pi` and `pi-acp` are launched as `pi-acp` — the npm package wraps the
binary in the ACP protocol. `opencode` is launched directly (or through
the bwrap wrapper if `programs.opencode-bwrap.enable = true` for the
user).

## 2. The templates

`local-templates/` is the **single source of truth** for the agent
configs. There are two subtrees:

```
local-templates/
├── opencode/
│   ├── opencode.json
│   └── skills/
│       └── emacs-emcp/
│           └── SKILL.md
└── pi/
    ├── extensions/
    │   └── pi-permission-system/
    │       └── config.json
    ├── mcp.json
    ├── models.json
    ├── settings.json
    └── skills/
        ├── emacs-emcp/
        │   └── SKILL.md
        └── safe-bash/
            └── SKILL.md
```

The deployment is in `modules/pro-agent-configs.nix`:

```nix
templateFiles = [
  { src = "local-templates/opencode/opencode.json";     dst = ".config/opencode/opencode.json"; }
  { src = "local-templates/pi/models.json";             dst = ".pi/agent/models.json"; }
  { src = "local-templates/pi/mcp.json";                dst = ".pi/agent/mcp.json"; }
  { src = "local-templates/pi/settings.json";           dst = ".pi/agent/settings.json"; }
  { src = "local-templates/pi/skills/emacs-emcp/SKILL.md"; dst = ".pi/agent/skills/emacs-emcp/SKILL.md"; }
  { src = "local-templates/opencode/skills/emacs-emcp/SKILL.md"; dst = ".config/opencode/skills/emacs-emcp/SKILL.md"; }
];
```

The activation script uses `install -m 0644 -o $(id -u) -g $(id -g)` to
avoid root-owned files after sudo-activation, and `copy_if_missing` to
never overwrite user edits.

A second activation appends to `~/.profile`:

```
# pro-nix: load AI provider keys from authinfo
[ -f "$HOME/.local/share/pro-nix/load-agent-env.sh" ] && . "$HOME/.local/share/pro-nix/load-agent-env.sh"
```

The marker is idempotent — it is only appended if the marker is not
already present.

The deployment step is replicated in `scripts/deploy-agent-configs.sh`
for non-NixOS hosts and for forced re-deploys. `just deploy-agents`
runs both that script and `install-pi-packages.sh`.

## 3. The MCP servers

Two MCP servers are registered in **both** `pi/mcp.json` and
`opencode/opencode.json`:

### `emcp`

The HTTP MCP server that lives inside Emacs, on
`http://127.0.0.1:38913/mcp`. The server is started by
`pro-emcp.el` (default `pro-emcp-server-auto-start = t`):

* On `after-init-hook`, `pro-emcp--auto-start-fn` runs.
* It checks for the `emcp` package; if absent, it bails silently.
* Otherwise, `(require 'emcp)` and `emcp-server-start`.
* The server binds to `127.0.0.1:38913` (loopback only — never
  exposed externally).
* Default profile is `'full-control` (inspect + get/set-variable +
  screenshot + eval + send-keys).

`emcp-tools-eval-default-policy` and
`emcp-tools-send-keys-default-policy` default to `'ask`. The agent
calling `emcp_eval` or `emcp_send_keys` opens a `*EMCP confirm*` buffer
in Emacs with the request, and the user chooses `y` / `n` / `a` /
`r` / `q`.

The MCP transport itself is the `http-server` package (also a fork
by `martenlienen`, the same author as `emcp`).

### `chrome-devtools`

```json
{
  "command": "npx",
  "args": ["-y", "chrome-devtools-mcp@latest", "--browser-url=http://127.0.0.1:9222"],
  "directTools": true,
  "lifecycle": "keep-alive"
}
```

Lives only on a host that has Chrome / Chromium running with
`--remote-debugging-port=9222`. pro-nix does not start Chrome
automatically; the user starts it when needed:

```bash
google-chrome-stable --remote-debugging-port=9222
```

When the server is reachable, the agent can navigate, click, take
screenshots, and evaluate JS in the browser.

### How `pi` reaches an MCP tool

`pi` does **not** expose MCP tools directly. It uses a **proxy tool**:

```
pi> mcp({tool: "emcp_apropos", args: {pattern: "pro-"}})
```

The `mcp` tool is registered by `pi-mcp-adapter`
(`local-templates/pi/settings.json#packages`). The agent calls it
with `{tool: ..., args: ...}`, the adapter routes to the right server,
and the response is returned to the agent.

### How `opencode` reaches an MCP tool

`opencode` exposes MCP tools **directly**, as if they were part of
its own tool list:

```
opencode> emcp_apropos(pattern: "pro-")
```

The MCP `tools/list` is queried at startup; the tools are added to
the agent's native function-calling surface.

> The asymmetry is a known wart. The `emacs-emcp` skill notes both
> calling conventions explicitly.

## 4. The skills

Skills are Markdown files that the agent loads on demand. The
mechanism is the same in both agents (a `SKILL.md` file in a
subdirectory of `skills/`). pro-nix ships two:

### `emacs-emcp`

`local-templates/{pi,opencode}/skills/emacs-emcp/SKILL.md` (137 / 123
lines).

Covers:

* **How to check the server is alive** — `curl -fsS http://127.0.0.1:38913/mcp`
  with the `initialize` request.
* **The `full-control` profile** — table of tools: `apropos`, `describe`,
  `find-definition`, `find-references`, `info-search`, `get-variable`,
  `set-variable`, `screenshot`, `eval`, `send-keys`. Plus the
  `info://{manual}/{node}` resource and the `/screenshot` prompt.
* **Typical scenarios** — "check a function is defined", "understand
  why the config is misbehaving", "check visual state", "safely fix a
  config".
* **Security** — `eval` and `send-keys` are gated by policy; the agent
  must wait for the user's `y` / `n` / `a` / `r` / `q` choice.
* **Troubleshooting** — when `emcp` is not visible to `pi`, run
  `emacsclient -e '(pro-emcp-server-start)'`.

The pi version has YAML frontmatter (`name`, `description`); the
opencode version does not (opencode discovers skills by directory
layout, not by frontmatter).

### `safe-bash`

`local-templates/pi/skills/safe-bash/SKILL.md` (307 lines, only in
pi — the opencode equivalent is implicit in the agent's own shell
tool).

Covers:

* **Classification** — every shell command is either *read-only* or
  *mutating*. Always report which.
* **Cross-platform considerations** — Windows vs Unix paths, `argv` vs
  `cmd /c`, package-manager detection (npm/pnpm/yarn).
* **Heredoc and quoting gotchas**.
* **Sudo and `expect`** — the rules for using `sudo` in scripts and the
  `expect` tool.
* **Destructive action confirmation** — patterns for asking before
  running `rm -rf`, `git push --force`, etc.

The skill is loaded by `pi` automatically when the agent starts
working on a task that involves shell commands.

## 5. The permission system

`local-templates/pi/extensions/pi-permission-system/config.json`
configures `@gotgenes/pi-permission-system`. The defaults are
**deny-by-pattern** for the most destructive operations:

### `path` rules

* **deny**: `.env*`, `secrets.*`, `*.pem`, `*.key`, `id_rsa*`,
  `id_ed25519*`, `~/.ssh/**`, `~/.aws/**`, `~/.gnupg/**`,
  `~/.pi/agent/auth.json`
* **ask**: `~/.pi/agent/models.json`

### `bash` rules

* **deny**: `rm -rf *`, `rm -rf /*`, `dd *`, `mkfs*`, fork bomb,
  `chmod 777`, `curl|sh`, `wget|sh`, `git push --force`,
  `nix-collect-garbage -d`, `kill -9 1`, `reboot`, `shutdown`
* **ask**: `sudo *`, `chown *`, `git push *`, `nix-env *`, `systemctl *`

### `mcp` / `skill` / `external_directory`

* `mcp *` — allow
* `skill *` — ask
* `external_directory` — ask

`yoloMode = false`, `debugLog = false`, `permissionReviewLog = true`.

The `opencode` agent has its own permission system, configured
through `opencode.json`. The pro-nix template keeps it permissive by
default — the user is expected to set their own rules.

## The end-to-end flow

When the user runs `pi -p "fix the typo on line 42 of main.py"`:

1. `pi` resolves the user message into an ACP request.
2. `pi-acp` is launched; it speaks ACP to the agent backend.
3. The backend is gptel-style (a remote LLM with tools).
4. The tool list includes `mcp({tool, args})` (proxied) plus the agent's
   own tools (read-file, write-file, run-shell).
5. The LLM decides to call `mcp({tool: "emcp_apropos", args: {pattern: "pro-"}})`.
6. `pi-mcp-adapter` routes the call to `emcp` (HTTP on 38913).
7. `emcp` (inside Emacs) executes `apropos "pro-"` in the live Emacs
   session.
8. Result is returned to the LLM.
9. LLM continues, eventually calling `shell.run` to fix the typo.
10. The shell command goes through the `bash` permission rules
    (deny-by-pattern) and the `safe-bash` skill is loaded on demand.
11. Result is formatted and returned to the user.

The same flow works for `opencode`, except MCP tools are called
directly (not through the `mcp` proxy).

## Deployment matrix

| Where | What |
|-------|------|
| NixOS activation | `home.activation.pro-agent-configs-deploy` (HM-owned) |
| `just deploy-agents` | `scripts/deploy-agent-configs.sh` + `scripts/install-pi-packages.sh` |
| `just switch-with-agents <host>` | switch + deploy + install in one |
| Manual | `cp local-templates/{pi,opencode}/* ~/.config/...` |

`deploy-agents.sh` is `copy_if_missing` — safe to run repeatedly.
`install-pi-packages.sh` is idempotent (re-runs only update
`settings.json` if the package list changed).
