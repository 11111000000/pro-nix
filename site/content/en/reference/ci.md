+++
title = "CI workflows"
sort_by = "weight"
template = "page.html"

[extra]
tldr = "All 15 GitHub Actions workflows + custom actions."
+++

# CI workflows

<span class="gen-badge">auto-gen</span> Generated 2026-06-16 from `.github/workflows/*.yml`.

> GitHub Actions runs on every push and PR. The `site-build.yml` workflow is the one that deploys this site to GitHub Pages; `site-preview.yml` builds a per-PR preview.

## Workflows

| File | Purpose (from header) |
|------|------------------------|
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

## Custom actions

| File | Purpose (from header) |
|------|------------------------|
| `.github/actions/check-change-gate/action.sh` | !/usr/bin/env bash · set -euo pipefail · Simple PR body Change Gate checker. Expects PR body in env var PR_BODY or reads from stdin. · BODY="${PR_BODY:-$(cat || true)}" |

---

## Required secrets (for full CI)

| Secret | Used by | Why |
|--------|---------|-----|
| `CACHIX_SIGNING_KEY` | `cachix-action` | Push built closures to the Cachix cache |

> Most workflows do not need any secret. The site-build workflow uses `actions/deploy-pages@v4` with the default `GITHUB_TOKEN`, which is provided automatically for public repos.
