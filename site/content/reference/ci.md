+++
title = "CI-workflow"
sort_by = "weight"
template = "page.html"

[extra]
tldr = "Все 15 GitHub Actions workflow + кастомные actions."
+++

# CI-workflow

<span class="gen-badge">auto-gen</span> Сгенерировано 2026-06-16 из `.github/workflows/*.yml`.

> GitHub Actions запускается на каждом push и PR. `site-build.yml` — это workflow, который деплоит этот сайт на GitHub Pages; `site-preview.yml` собирает preview для каждого PR.

## Workflows

| Файл | Назначение (из шапки) |
|------|----------------------|
| `.github/workflows/change-gate.yml` | Change Gate Validator (non-blocking initially) |
| `.github/workflows/ci.yml` | CI |
| `.github/workflows/elisp-parens.yml` | Emacs Lisp Paren Check |
| `.github/workflows/emacs-ci.yml` | Emacs CI |
| `.github/workflows/emacs-e2e.yml` | Emacs E2E |
| `.github/workflows/emacs-headless.yml` | Emacs Headless CI |
| `.github/workflows/flake-check.yml` | Flake Check and Contract Tests |
| `.github/workflows/gui-smoke.yml` | GUI Smoke |
| `.github/workflows/hds-verify.yml` | HDS Verify |
| `.github/workflows/holo-verify-fast.yml` | Holo Verify (fast) |
| `.github/workflows/lint-and-tests.yml` | Lint and E2E Tests |
| `.github/workflows/opencode-check.yml` | Opencode Checks |
| `.github/workflows/opencode-smoke.yml` | Opencode smoke |
| `.github/workflows/unit-ci.yml` | Unit CI (flake + unit tests) |
| `.github/workflows/validate-pr.yml` | Validate PR |

## Кастомные actions

| Файл | Назначение (из шапки) |
|------|----------------------|
| `.github/actions/check-change-gate/action.sh` | !/usr/bin/env bash · set -euo pipefail · Simple PR body Change Gate checker. Expects PR body in env var PR_BODY or reads from stdin. · BODY="${PR_BODY:-$(cat || true)}" |

---

## Требуемые секреты (для полного CI)

| Секрет | Используется | Зачем |
|--------|--------------|-------|
| `CACHIX_SIGNING_KEY` | `cachix-action` | Push собранных closure'ов в Cachix-кеш |

> Большинству workflow'ов секреты не нужны. site-build workflow использует `actions/deploy-pages@v4` со стандартным `GITHUB_TOKEN`, который выдаётся автоматически для публичных репозиториев.
