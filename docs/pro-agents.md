# Agent setup

## Included tools

- `goose`
- `aider`
- `opencode`
- `agent-shell` inside Emacs
- `llm-lab` for notebooks and local LLM research

## Default behavior

All three commands are expected to be present on PATH after the system profile is installed.

## goose

1. Run `goose configure`.
2. Pick a provider or ACP adapter.
3. Use `goose session` for interactive work.

## aider

1. Run `aider` from a repo checkout.
2. If this is the first run, install the cached Python tool once with `pipx install aider-chat`.
3. Authenticate with the target provider using the upstream aider flags.

## opencode

1. Run `opencode` from a repo checkout.
2. Keep provider credentials in the environment or the tool's own config.

## llm-lab

1. Run `llm-lab` from a repo checkout.
2. Use it for Jupyter notebooks, prompt experiments, dataset inspection, and quick evaluation loops.
3. Keep durable findings in docs or committed analysis files, not only in notebook state.

## agent-shell

1. Install it from MELPA through the Emacs package layer.
2. Open it from the existing Emacs AI entrypoint.
3. It follows the repo's `gptel` and provider policy.
4. In this repo, `C-c A` is bound to `pro-agent-open`.

## Policy

- Do not store API keys in Nix files.
- Prefer env vars or `auth-source` for secrets.
- Keep agent installation paths documented in text so they stay checkable.
- Keep notebook outputs deterministic where possible and pin research dependencies through Nix.
