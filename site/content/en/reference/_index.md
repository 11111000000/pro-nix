+++
title = "Reference"
sort_by = "weight"
template = "section.html"

[extra]
tldr = "Auto-generated catalogues: NixOS options, defcustom knobs, key bindings, scripts, submodules, tests, CI, AI models, and a glossary."
+++

Every page in this section is **generated** by a small script in
`scripts/site-extract-*.{sh,py}` from the actual source. If the source moves,
the page moves with it on the next `just site-regen`.

| Page | Source | Generator |
|------|--------|-----------|
| [NixOS options](reference/options.md) | 6 module files | `tools/generate-options-md.sh` (existing) |
| [defcustom knobs](reference/defcustom.md) | `emacs/base/modules/pro-*.el` | `scripts/site-extract-defcustom.py` |
| [Keys](reference/keys.md) | `emacs-keys.org` | `scripts/site-extract-keys.py` |
| [Scripts](reference/scripts.md) | `scripts/*.sh`, `bin/*` | `scripts/site-extract-scripts.sh` |
| [Submodules](reference/submodules.md) | `.gitmodules` + submodule READMEs | `scripts/site-extract-submodules.py` |
| [Tests](reference/tests.md) | `tests/**` | `scripts/site-extract-tests.py` |
| [CI workflows](reference/ci.md) | `.github/workflows/*.yml` | `scripts/site-extract-ci.py` |
| [AI models](reference/ai-models.md) | `emacs/base/modules/ai-models.json` | `scripts/site-extract-ai-models.py` |
| [Glossary](reference/glossary.md) | hand-maintained | `site/content/reference/glossary.md` |

The auto-gen pages are tagged with a small badge in the corner — `<span
class="gen-badge">auto-gen</span>`. They are intentionally not edited by hand;
if you want to change one, change the source and run `just site-regen`.

## Why auto-generate

* **Drift-proof.** If a `defcustom` is added or removed, the reference reflects
  it on the next build — no missed docs.
* **Single source of truth.** The script reads the same `.el` file the user
  loads; the docs cannot lie.
* **Cheap.** Each script is 30-60 lines of Python. No external dependencies
  beyond stdlib + `tomli`/`pyyaml` if you choose to use them.

## What is *not* auto-generated

* **Glossary.** Hand-maintained; the terms are project-specific and need
  editorial judgment.
* **Hosts pages** (under `/hosts/`). Each is a design story, not a fact dump.
* **Principles, Workflow, Conventions.** These are explanations, not data.

## Regenerate the site

```bash
just site-regen       # regenerate every auto-gen page
just site-serve       # local preview with live reload
just site-build       # produce the final static output
```

`just site-regen` is idempotent. It does not touch pages it does not own. The
generated files live under `site/content/reference/` and are checked in (so
`zola build` works without Python); a `git status` after a regen shows you
exactly what changed.
