+++
title = "Сабмодули"
sort_by = "weight"
template = "page.html"

[extra]
tldr = "Все 11 git-сабмодулей. Каждый — это upstream Emacs-пакет, от которого зависит репо."
+++

# Сабмодули

<span class="gen-badge">auto-gen</span> Сгенерировано 2026-06-16 из `.gitmodules` и README сабмодулей.

> Все сабмодули настроены на **HTTPS** в `.gitmodules` по умолчанию. Чтобы переключиться на SSH для write-доступа, запустите `just submodules-ssh` (см. [Рабочий процесс → сабмодули](workflow/submodules.md)).

| Имя | Путь | URL | Ветка | Описание одной строкой |
|------|------|-----|--------|----------------------|
| `submodules/pro-tabs` | `submodules/pro-tabs` | github.com/gnu-emacs-ru/pro-tabs | (default) | *pro-tabs-mode* — a modern and customizable mode that unifies Emacs tab-bar and tab-line into a singular beautiful style: with modern icons, a sleek appearance, glyphs, wavy colorful separators, and no excessive buttons. The main goal is to make the standard Emacs tabs aesthetic, clear, and consistently styled both in  |
| `submodules/carriage` | `submodules/carriage` | github.com/gnu-emacs-ru/carriage | (default) | * Философия Carriage — не «агент». Это управляемый, надёжный и простой «станок для кода»: вы задаёте режим, контекст, а инструмент аккуратно реализует изменения, предлагает комманды, фиксирует отпечаток каждого прохода, показывает отчёты и всегда даёт возможность остановки. Принципы: - Прямой путь к результату: минимал |
| `submodules/emcp` | `submodules/emcp` | codeberg.org/martenlienen/emcp | (default) | EMCP lets your LLM agent interact with Emacs. The agent can look up documentation and definitions, take screenshots, read buffers, execute code and more. Exactly which [[#built-in-prompts][prompts]], [[#built-in-resources][resources]] and [[#built-in-tools][tools]] are available to the agent depends on the active [[#pr |
| `submodules/telega.el` | `submodules/telega.el` | github.com/zevlg/telega.el | (default) | ![logo](etc/telega-logo.svg) telega.el See [Telega Manual](https://zevlg.github.io/telega.el/) for comprehensive documentation. **Latest telega.el release can be found in the https://github.com/zevlg/telega.el/tree/release-0.8.0 branch, it is compatible with the latest TDLib major release 1.8.0** --- `telega.el` is ful |
| `submodules/agent-shell` | `submodules/agent-shell` | github.com/11111000000/agent-shell | main | [[https://melpa.org/#/agent-shell][file:https://melpa.org/packages/agent-shell-badge.svg]] 👉 [[https://github.com/sponsors/xenodium][Support this work via GitHub Sponsors]] by [[https://github.com/xenodium][@xenodium]] (check out my [[https://xenodium.com][blog]]) [[file:agent-shell.png]] * This project needs your fund |
| `submodules/acapella` | `submodules/acapella` | github.com/gnu-emacs-ru/acapella | (default) | * Acapella Acapella is an Emacs package that lets you talk to AI agents through the open A2A protocol (JSON-RPC over HTTP + SSE streaming). It provides a small, composable, testable core with an Emacs-first UI: send or stream messages, manage long-running tasks (get/cancel/resubscribe/list), preview artifacts safely, a |
| `submodules/atlas` | `submodules/atlas` | github.com/gnu-emacs-ru/atlas | (default) | * What is Atlas? Atlas is a universal, extensible project map for Emacs. It inventories files, extracts symbols (functions, classes, variables, …), connects them with typed edges (import/require/provide/call/ref/…), and keeps everything in a deterministic store you can query, visualize, and export for LLM work. [[./atl |
| `submodules/tao-theme` | `submodules/tao-theme` | github.com/11111000000/tao-theme-emacs | (default) | Colors blind people's eyes; -- Lao Tzu, Tao Te Ching, Ch. 12	Sentence 1 * Tao theme Two uncoloured color themes for Emacs: tao-yin and tao-yang. ** Installation Tao in [[https://melpa.org/#/tao-theme][MELPA]] `M-x package-install tao-theme` or alternatively: `M-x package-install-file tao-theme` ** Customization By defa |
| `submodules/shaoline` | `submodules/shaoline` | github.com/11111000000/shaoline | (default) | “The mode-line that can be seen is not the eternal mode-line.” — Lao-Tzu, ~Emacs 27 + edition~ [[file:screenshot-shaoline.png]] There was an age when every buffer carried a heavy belt of glyphs, digits and blinking widgets. Then a humble Lisp script shaved its head, sat down in the echo area and simply /was/. That scri |
| `submodules/agent-shell-hud` | `submodules/agent-shell-hud` | github.com/11111000000/agent-shell-hud.git | main | [[https://github.com/11111000000/agent-shell-hud/actions][file:https://img.shields.io/badge/license-GPL--3.0-blue.svg]] [[https://www.gnu.org/software/emacs/][file:https://img.shields.io/badge/Emacs-29.1+-blueviolet.svg]] [[https://github.com/11111000000/agent-shell-hud][file:https://img.shields.io/badge/version-0.1.0- |
| `submodules/acp` | `submodules/acp` | github.com/xenodium/acp.el | (default) | * This project needs your funding As you pay for those useful LLM tokens, consider [[https://github.com/sponsors/xenodium][sponsoring]] development and maintenance of this project. =acp.el= enables us to build better integrations and tools into our beloved Emacs text editor. With your help, I can make this effort more  |

---

## Как сабмодули подключаются в Nix

`nix/emacs-recipes/*.nix` собирают каждый сабмодуль в `emacsPackages`-деривацию. Рецепты лежат в `nix/emacs-recipes/` и подтягиваются overlay'ом `nix/overlays/emacs-extra.nix`.

Некоторые сабмодули — **форкнутые** для pro-nix (например, `agent-shell`, `agent-shell-hud`, `shaoline`, `tao-theme`); upstream-URL'ы в таблице выше указывают на репозиторий форка.
