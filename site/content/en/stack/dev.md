+++
title = "Dev tooling"
template = "page.html"
weight = 6

[extra]
tldr = "Haskell toolchain (ghc + HLS + fourmolu + hlint), LSP servers for Python/Java/Rust/Go/Bash, Docker + lazydocker + trivy + hadolint, microservice template with sops."

[[extra.next]]
title = "NixOS layer"
url = "/stack/nixos/"

[[extra.next]]
title = "Architecture overview"
url = "/architecture/"
+++

# Dev tooling

The dev layer is **purpose-built for one developer** (the repo owner)
and is opt-in per host. `huawei` carries the heaviest composition;
`cf19` is the minimal dev surface; `vm` is a middle ground for testing.

## Haskell

`modules/pro-haskell.nix` — host-imported only on `huawei`.

Packages: `ghc`, `haskell-language-server`, `cabal-install`, `stack`,
`ghcid`, `hlint`, `fourmolu`.

The Emacs side (`emacs/base/modules/pro-haskell.el`) wires `haskell-mode`
+ `haskell-indentation` + `haskell-doc` + `haskell-cabal`, then registers
`haskell-language-server-wrapper` as the eglot LSP server. Five
interactive commands:

* `M-x pro-haskell-load-buffer` — load the current buffer in the cabal/ghci REPL.
* `M-x pro-haskell-switch-to-repl` — pop to the REPL.
* `M-x pro-haskell-format-buffer` — `fourmolu` (C-c h f).
* `M-x pro-haskell-lint` — `hlint` (C-c h i).
* `M-x pro-haskell-browse-haddock` — Haddock for the symbol at point (C-c h d).

The LSP server program is `pro-haskell-lsp-server-program`, default
`("haskell-language-server-wrapper" "--lsp")`.

`ghcup` is **not** in the project — every Haskell tool comes from
nixpkgs.

## LSP servers

`system-package-sets-lsp.nix` is a **function** that returns the
optional LSP packages. Each is `maybe` (returns `[]` if the upstream
package is missing):

* `pyright` (from nodePackages) — Python.
* `jdtls` — Java (downloads Eclipse JDT Language Server on first run).
* `rust-analyzer` — Rust.
* `gopls` (from goPackages) — Go.
* `bash-language-server` (from nodePackages) — Bash.

The `gptel` "completion for code" feature is *not* an LSP — it uses
gptel directly with a code-aware prompt.

## Docker and lazydocker

`modules/pro-docker.nix` enables `virtualisation.docker`. It also
creates a custom bridge `pro-dev` (172.20.0.0/16, gateway 172.20.0.1)
via a oneshot service. The `writeShellScriptBin` indirection is a
workaround for a systemd < 258 argv-parsing bug with `2>` / `||` adjacent
in `ExecStart`.

Packages: `docker`, `docker-compose`, `docker-credential-helpers`,
plus the operator stack: `lazydocker`, `dive`, `ctop`, `trivy`,
`hadolint`, `sops`, `age`.

The `just` surface has ten Docker recipes:

```bash
just d              # lazydocker
just dl NAME        # docker logs -f --tail 100 NAME
just dsh NAME [CMD] # docker exec -it NAME CMD (default sh)
just dr NAME        # docker restart NAME + sleep 1 + logs --tail 30
just dprune         # docker system/image/network prune -f
just dscan IMAGE [SEVERITY]   # trivy image --severity HIGH,CRITICAL
just dlint DOCKERFILE         # hadolint
just dup            # docker compose up -d
just ddown          # docker compose down
just dps            # docker compose ps
just dclogs         # docker compose logs -f --tail 50
```

## The microservice template

`templates/microservice/` — a self-contained starter for a new
containerised service. Contents:

* `Dockerfile` — `alpine:3.20`, `tini`, `ca-certificates`, non-root user
  `app` (UID 1000), `pip install -r requirements.txt`.
* `compose.yaml` — `my-svc` with `external: true` on the `pro-dev`
  network, healthcheck `wget /healthz`, `${SERVICE_PORT:-8000}` host
  mapping, `restart: unless-stopped`, code volume mount.
* `justfile` — `build`, `up`, `down`, `restart SERVICE`, `logs`,
  `logs-svc`, `sh`, `ps`, `scan` (trivy), `lint` (hadolint),
  `encrypt-secrets`, `decrypt-secrets`, `clean`.
* `.sops.yaml` — regex `.*\.sops\.ya?ml$`, age recipient placeholder.
* `.env.sops.yaml.example` — `SERVICE_PORT`, `LOG_LEVEL`,
  `DATABASE_URL`, `API_KEY`, `JWT_SECRET` (CHANGE_ME placeholders).
* `.gitignore` — ignores `.env` and `keys/*.age`.

Use the template:

```bash
cp -r templates/microservice ~/my-svc
cd ~/my-svc
# Edit Dockerfile, compose.yaml, requirements.txt
just build
just up
just scan    # trivy
just encrypt-secrets    # sops --encrypt --in-place
```

## The npm template

`templates/.opencode/config.json` — a stub opencode config with the
`aitunnel` provider (host `api.aitunnel.ru`, empty token, model
`gpt-5.4-mini`), `autoUpdatePlugins: false`, `telemetry: false`. Copy
into a project as `.opencode/config.json` to give the agent a default
context.

## Nix-side tooling

`modules/pro-dev.nix` (host-imported on `huawei` via composition) brings
in:

* `direnv`, `shellcheck`, `shfmt`, `bat`, `tldr`, `pipx`.
* `nodejs_20`, `esbuild`, `prettier`, `typescript-language-server`,
  `typescript`.
* `rust-analyzer`, `bash-language-server`.
* `cmake`, `gcc`, `clang`, `binutils`, `gnumake`, `pkg-config`,
  `libtool`, `automake`, `autoconf`, `ncurses`.
* `ag` (silver-searcher), `pt` (the_platinum_searcher), `fzf`, `lnav`.
* `mosh`, `pandoc`, `graphviz`, `plantuml`, `mermaid-cli`.
* `emacsPackages.eldev`, `emacsPackages.cask`.

Plus the container stack (see above).

The `llm-lab` wrapper around `python3.withPackages [jupyterlab, ipykernel,
transformers, datasets, sentencepiece, tokenizers, numpy, pandas,
matplotlib, scipy, plotly, seaborn]` is in
`system-package-sets-dev.nix` — a one-shot for ad-hoc ML experiments.

## The decisions file

`templates/decisions.el.example` — example user-level Emacs config
that overrides the auto-install policy:

```elisp
(setq pro-packages-decisions
      '((gptel . always)        ; always install from MELPA, even if Nix provides it
        (magit . always)
        (somepkg . never)))     ; never install, even if requested
```

Drop this in `~/.config/emacs/decisions.el` and `pro-packages--maybe-install`
will respect it.
