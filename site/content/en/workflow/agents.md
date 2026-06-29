+++
title = "Agents"
template = "page.html"
weight = 4

[extra]
tldr = "just deploy-agents runs deploy-agent-configs.sh + install-pi-packages.sh. copy_if_missing semantics. The ~/.authinfo → ~/.profile chain exposes AITUNNEL_KEY, OPENROUTER_KEY, OPENAI_API_KEY, MISTRAL_API_KEY, MINIMAX_API_KEY, DEEPSEEK_API_KEY."

[[extra.next]]
title = "Keys"
url = "/workflow/keys/"

[[extra.next]]
title = "Soft-reload"
url = "/workflow/reload/"
+++

# Agents

The agent layer is deployed by `just deploy-agents`. The two
scripts behind it are mirror images of the NixOS activation
(`modules/pro-agent-configs.nix`): the script is the manual
equivalent for non-NixOS hosts and for forced re-deploys.

## The deployment surface

`modules/pro-agent-configs.nix` defines 6 file copies:

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

Plus the `home.file.".local/share/pro-nix/load-agent-env.sh"`
executable, which is sourced from `~/.profile` (also added by the
activation).

The `scripts/deploy-agent-configs.sh` script replicates all 6 copies
plus the skills trees (`emacs-emcp` and `safe-bash`) plus a
project-local `$PWD/.pi/{models,opencode}.json` if `$PWD/.pi/`
does not exist.

## `copy_if_missing` semantics

The activation and the script use **copy-if-missing** semantics:

* If the destination file does not exist, install it with
  `install -m 0644 -o $(id -u) -g $(id -g) <src> <dst>`.
* If the destination file exists, do nothing.
* The destination is *never* overwritten.

This is enforced by the script logic:

```bash
copy_if_missing() {
  if [ ! -e "$dst" ]; then
    install -m 0644 -o "$(id -u)" -g "$(id -g)" "$src" "$dst" \
      || cp "$src" "$dst" \
      || echo "WARN: cannot install $dst"
  fi
}
```

To force a re-deploy:

```bash
rm ~/.config/opencode/opencode.json
just deploy-agents
```

The script also has a fallback to plain `cp` (no chown) for cases
where `install` is not available. The chown is the important
detail — it prevents the "file owned by root after sudo-activation"
problem that breaks `pi` (which refuses to rewrite its own
`models.json` if it's not user-owned).

## The `~/.pi/agent/auth.json` invariant

`pi` creates `~/.pi/agent/auth.json` on first run. The file is in
the **deny** list of the permission system
(`local-templates/pi/extensions/pi-permission-system/config.json`):

```json
"path": {
  "deny": ["~/.pi/agent/auth.json", ...]
}
```

The deploy script **never** writes to `auth.json`. It is purely
the agent's file. The deployment leaves it untouched.

## `just install-pi-packages`

After the templates are in place, `just install-pi-packages` runs
`scripts/install-pi-packages.sh`:

1. Locate `pi` on `$PATH`. If missing, fail fast.
2. Read `~/.pi/agent/settings.json` (the deployed one, not the
   template — the user may have edited it). Fall back to the
   template if the deployed one is missing.
3. Parse the `packages` array with `python3 -c "import json; ..."`.
4. For each `npm:` package, run `pi install npm:<pkg>`.
5. Aggregate failures. `exit 0` if all succeed, `exit 1` otherwise.

The `--dry-run` flag prints the commands without executing.

`pi install` is itself idempotent: re-running it after a successful
install just updates `settings.json` (no-op for already-installed
packages).

## The auth chain: `~/.authinfo` → `load-agent-env.sh`

The `home.file.".local/share/pro-nix/load-agent-env.sh"`
executable is **the** secret-loading script. It reads `~/.authinfo`
(or `~/.authinfo.gpg` if it exists and `gpg` is available), parses
the authinfo format, and exports the env vars that the templates
reference.

### The map

```bash
declare -A _pro_agent_targets=(
  ["api.aitunnel.ru:token"]="AITUNNEL_KEY AITUNNEL_API_KEY"
  ["openrouter.ai:token"]="OPENROUTER_KEY OPENROUTER_API_KEY"
  ["api.openai.com:openai"]="OPENAI_API_KEY"
  ["api.mistral.ai:token"]="MISTRAL_API_KEY MISTRAL_API_KEY"
  ["api.minimax.io:token"]="MINIMAX_API_KEY MINIMAX_KEY"
  ["api.deepseek.com:token"]="DEEPSEEK_API_KEY DEEPSEEK_KEY"
)
```

Each `host:user` key in the authinfo file is mapped to **one or
two env vars**. The script:

1. Reads the authinfo line by line.
2. For each `machine X login Y password Z` triple, looks up
   `_pro_agent_targets[X:Y]`.
3. If a match is found, exports the env vars (skipping if the
   first one is already set — "first wins").
4. Cleans up the temp GPG output if it was used.

### GPG mode

If `~/.authinfo.gpg` exists and `gpg` is available, the script:

```bash
_authinfo_path="$(mktemp)"
trap "rm -f '$_authinfo_path'" EXIT
gpg --quiet --batch --decrypt "$HOME/.authinfo.gpg" > "$_authinfo_path" 2>/dev/null
```

The temp file is `0600`, owned by the current user, and removed
on EXIT. GPG prompt for the passphrase comes from the agent
(`gpg-agent`).

### Idempotency

The script guards itself with `PRO_AGENT_ENV_LOADED`:

```bash
[ -n "${PRO_AGENT_ENV_LOADED:-}" ] && return 0 2>/dev/null || true
[ -n "${PRO_AGENT_ENV_LOADED:-}" ] && exit 0
...
export PRO_AGENT_ENV_LOADED=1
```

Sourcing the file twice in the same shell is a no-op.

## The `~/.profile` line

The activation appends this to `~/.profile`:

```bash
# pro-nix: load AI provider keys from authinfo
[ -f "$HOME/.local/share/pro-nix/load-agent-env.sh" ] && . "$HOME/.local/share/pro-nix/load-agent-env.sh"
```

The marker (`# pro-nix: load AI provider keys from authinfo`) makes
the append idempotent — the activation only appends if the marker
is not already present. The `[ -f ... ]` guard means the source
line is silently skipped if the script is missing (it would only
be missing on a non-NixOS host that has not run `just
deploy-agents`).

## MCP servers — what gets registered

`local-templates/pi/mcp.json` and `local-templates/opencode/opencode.json`
both have:

```json
{
  "mcpServers": {
    "chrome-devtools": {
      "command": "npx",
      "args": ["-y", "chrome-devtools-mcp@latest", "--browser-url=http://127.0.0.1:9222"],
      "directTools": true,
      "lifecycle": "keep-alive"
    },
    "emcp": {
      "url": "http://127.0.0.1:38913/mcp"
    }
  }
}
```

The deployment is a straight copy. The user can edit the
deployed copy to add more MCP servers, and the deploy will not
overwrite it (copy_if_missing).

## The deploy-agents flow

```
just deploy-agents
  └── scripts/deploy-agent-configs.sh
       ├── copy_if_missing opencode/opencode.json → ~/.config/opencode/
       ├── copy_tree_if_missing opencode/skills/ → ~/.config/opencode/skills/
       ├── copy_if_missing pi/models.json → ~/.pi/agent/
       ├── copy_if_missing pi/mcp.json → ~/.pi/agent/
       ├── copy_if_missing pi/settings.json → ~/.pi/agent/
       ├── copy_tree_if_missing pi/skills/ → ~/.pi/agent/skills/
       ├── (project-local) copy_if_missing $PWD/.pi/models.json
       └── (project-local) copy_if_missing $PWD/.pi/opencode.json
  └── scripts/install-pi-packages.sh
       └── pi install npm:<pkg> for every package in settings.json
```

The first deploy on a fresh host is **slow** (npm install for
each package). Subsequent deploys are **fast** (no-op).

## The full chain for a new host

```bash
# On the new host
git clone https://github.com/11111000000/pro-nix
cd pro-nix
git submodule update --init --recursive
sudo just switch <host>             # boots the NixOS config
just deploy-agents                  # templates + npm
emacsclient -e '(pro-emcp-server-start)'   # start the emcp server
pi -p 'mcp({})'                       # should show 2/2 servers
```

If `pi -p 'mcp({})'` shows `0/2`, EMCP did not start. See
[Troubleshooting](workflow/troubleshoot.md).
