<!-- Русский: комментарии и пояснения оформлены в стиле учебника -->
# Agent tooling matrix

## Goal

Make the common open-source agents immediately available in this repo and document the exact setup path for each one.

## Selected tools

| Tool | Status in repo | Install path | Notes |
| --- | --- | --- | --- |
| `goose` | bundled | `system-packages.nix` | Rust CLI from nixpkgs, available on PATH |
| `opencode` | bundled | `system-packages.nix` | CLI wrapper over the upstream npm package |
| `aider` | bundled | `system-packages.nix` | PATH wrapper that uses `pipx` bootstrap for `aider-chat` |
| `llm-lab` | bundled | `system-packages.nix` | JupyterLab + HF/data science stack for local LLM research |

## Emacs package

- `agent-shell` is installed from MELPA through the Emacs package layer.
- `gptel` stays in the package bootstrap list because `agent-shell` depends on it in this config.
- `C-c A` opens `agent-shell` via `pro-agent-open`.
- `llm-lab` is the companion notebook environment for model inspection, prompt tests, dataset exploration, and RAG prototyping.

## Why these tools

1. `goose` gives a native agent shell with ACP/provider support.
2. `aider` is the simplest open-source git-native editor for existing codebases.
3. `opencode` is already part of the repo's AI workflow and stays as a low-friction terminal agent.
4. `llm-lab` fills the research gap: notebooks, kernel, datasets, transformers, and plotting in one reproducible shell.

## Configuration contract

1. Secrets stay out of Nix.
2. Provider keys live in `auth-source` or shell environment variables.
3. Agent commands must be available without extra repo-specific bootstrap steps.
4. If a tool is fetched lazily, document that explicitly.
5. Research notebooks must not become a hidden source of truth; durable outputs go into docs or committed analysis artifacts.

## User setup

### goose

- Run `goose configure`.
- Pick an ACP/provider mode that matches your subscription or API key.
- For the existing repo defaults, `GOOSE_PROVIDER=codex-acp` or `GOOSE_PROVIDER=claude-acp` are supported by goose itself.

### aider

- `aider` is exposed on PATH.
- `pipx` is available for the underlying Python environment.
- If the wrapper has not cached `aider-chat` yet, run `pipx install aider-chat` once.
- Recommended invocation: `aider --model <model> --api-key <provider>=<key>`.

### opencode

- `opencode` is exposed on PATH.
- It is wrapped around the upstream `@opencode/cli` package.
- If needed, configure provider keys in the shell before launch.

### llm-lab

- Run `llm-lab` to open JupyterLab in a reproducible environment.
- Use it for prompt experiments, dataset probes, embedding comparisons, and lightweight evaluation notebooks.
- Save only committed reports or notebooks that are intentionally part of the repo.

## Repo integration

1. `system-packages.nix` carries the runtime commands.
2. `docs/opencode-integration.md` remains the short install note.
3. This file is the matrix and policy source for which agent belongs in PATH.
4. `llm-lab` is the default research surface for local LLM experiments.
