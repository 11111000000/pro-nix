+++
title = "Инструменты разработчика"
template = "page.html"
weight = 6

[extra]
tldr = "Haskell-тулчейн (ghc + HLS + fourmolu + hlint), LSP-серверы для Python/Java/Rust/Go/Bash, Docker + lazydocker + trivy + hadolint, microservice-шаблон с sops."

[[extra.next]]
title = "Слой NixOS"
url = "/stack/nixos/"

[[extra.next]]
title = "Обзор архитектуры"
url = "/architecture/"
+++

# Инструменты разработчика

Слой dev — **сделан для одного разработчика** (владельца репо) и
подключается per host. `huawei` несёт самую тяжёлую composition;
`cf19` — минимальную dev-поверхность; `vm` — промежуточный
вариант для тестов.

## Haskell

`modules/pro-haskell.nix` — импортируется хостом только на `huawei`.

Пакеты: `ghc`, `haskell-language-server`, `cabal-install`, `stack`,
`ghcid`, `hlint`, `fourmolu`.

Emacs-сторона (`emacs/base/modules/pro-haskell.el`) подключает
`haskell-mode` + `haskell-indentation` + `haskell-doc` +
`haskell-cabal`, затем регистрирует `haskell-language-server-wrapper`
как eglot LSP-сервер. Пять интерактивных команд:

* `M-x pro-haskell-load-buffer` — загрузить текущий буфер в
  cabal/ghci REPL.
* `M-x pro-haskell-switch-to-repl` — переключиться на REPL.
* `M-x pro-haskell-format-buffer` — `fourmolu` (C-c h f).
* `M-x pro-haskell-lint` — `hlint` (C-c h i).
* `M-x pro-haskell-browse-haddock` — Haddock для символа под
  курсором (C-c h d).

Программа LSP-сервера — `pro-haskell-lsp-server-program`, по
умолчанию `("haskell-language-server-wrapper" "--lsp")`.

`ghcup` **не** в проекте — каждый Haskell-инструмент приходит из
nixpkgs.

## LSP-серверы

`system-package-sets-lsp.nix` — это **функция**, которая возвращает
опциональные LSP-пакеты. Каждый — `maybe` (возвращает `[]`, если
upstream-пакет отсутствует):

* `pyright` (из nodePackages) — Python.
* `jdtls` — Java (скачивает Eclipse JDT Language Server на первом
  запуске).
* `rust-analyzer` — Rust.
* `gopls` (из goPackages) — Go.
* `bash-language-server` (из nodePackages) — Bash.

«Completion for code» в gptel — это **не** LSP; gptel используется
напрямую с code-aware prompt.

## Docker и lazydocker

`modules/pro-docker.nix` включает `virtualisation.docker`. Также
создаёт кастомный мост `pro-dev` (172.20.0.0/16, gateway 172.20.0.1)
через oneshot-сервис. `writeShellScriptBin`-перенаправление — это
обход бага argv-парсинга в systemd < 258 с `2>` / `||` рядом в
`ExecStart`.

Пакеты: `docker`, `docker-compose`, `docker-credential-helpers`,
плюс стек оператора: `lazydocker`, `dive`, `ctop`, `trivy`,
`hadolint`, `sops`, `age`.

В `just` есть десять Docker-рецептов:

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

## Microservice-шаблон

`templates/microservice/` — самодостаточный стартер для нового
контейнеризованного сервиса. Содержимое:

* `Dockerfile` — `alpine:3.20`, `tini`, `ca-certificates`,
  непривилегированный user `app` (UID 1000), `pip install -r
  requirements.txt`.
* `compose.yaml` — `my-svc` с `external: true` на сети `pro-dev`,
  healthcheck `wget /healthz`, `${SERVICE_PORT:-8000}` host mapping,
  `restart: unless-stopped`, code volume mount.
* `justfile` — `build`, `up`, `down`, `restart SERVICE`, `logs`,
  `logs-svc`, `sh`, `ps`, `scan` (trivy), `lint` (hadolint),
  `encrypt-secrets`, `decrypt-secrets`, `clean`.
* `.sops.yaml` — regex `.*\.sops\.ya?ml$`, age recipient placeholder.
* `.env.sops.yaml.example` — `SERVICE_PORT`, `LOG_LEVEL`,
  `DATABASE_URL`, `API_KEY`, `JWT_SECRET` (CHANGE_ME плейсхолдеры).
* `.gitignore` — игнорирует `.env` и `keys/*.age`.

Использовать шаблон:

```bash
cp -r templates/microservice ~/my-svc
cd ~/my-svc
# Отредактируйте Dockerfile, compose.yaml, requirements.txt
just build
just up
just scan    # trivy
just encrypt-secrets    # sops --encrypt --in-place
```

## npm-шаблон

`templates/.opencode/config.json` — заглушка opencode-конфига с
провайдером `aitunnel` (host `api.aitunnel.ru`, пустой токен,
модель `gpt-5.4-mini`), `autoUpdatePlugins: false`,
`telemetry: false`. Скопируйте в проект как `.opencode/config.json`,
чтобы дать агенту дефолтный контекст.

## Nix-инструменты

`modules/pro-dev.nix` (импортируется хостом на `huawei` через
composition) приносит:

* `direnv`, `shellcheck`, `shfmt`, `bat`, `tldr`, `pipx`.
* `nodejs_20`, `esbuild`, `prettier`, `typescript-language-server`,
  `typescript`.
* `rust-analyzer`, `bash-language-server`.
* `cmake`, `gcc`, `clang`, `binutils`, `gnumake`, `pkg-config`,
  `libtool`, `automake`, `autoconf`, `ncurses`.
* `ag` (silver-searcher), `pt` (the_platinum_searcher), `fzf`,
  `lnav`.
* `mosh`, `pandoc`, `graphviz`, `plantuml`, `mermaid-cli`.
* `emacsPackages.eldev`, `emacsPackages.cask`.

Плюс контейнерный стек (см. выше).

`llm-lab`-обёртка вокруг
`python3.withPackages [jupyterlab, ipykernel, transformers, datasets,
sentencepiece, tokenizers, numpy, pandas, matplotlib, scipy,
plotly, seaborn]` живёт в `system-package-sets-dev.nix` —
одноразовый для ad-hoc ML-экспериментов.

## Файл решений

`templates/decisions.el.example` — пример пользовательского
Emacs-конфига, который переопределяет политику auto-install:

```elisp
(setq pro-packages-decisions
      '((gptel . always)        ; всегда ставить из MELPA, даже если Nix даёт
        (magit . always)
        (somepkg . never)))     ; никогда не ставить, даже если просят
```

Положите это в `~/.config/emacs/decisions.el`, и
`pro-packages--maybe-install` будет это уважать.
