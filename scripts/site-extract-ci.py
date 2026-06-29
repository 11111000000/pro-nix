#!/usr/bin/env python3
"""List .github/workflows/*.yml into a Zola reference page (both languages)."""
import pathlib
import re
import datetime

REPO = pathlib.Path(__file__).resolve().parent.parent
WF = REPO / ".github" / "workflows"
ACTIONS = REPO / ".github" / "actions"
SITE = REPO / "site" / "content"

def first_meaningful(path, n=3):
    out = []
    for line in path.read_text(errors="replace").splitlines():
        s = line.strip()
        if not s:
            continue
        if s.startswith("name:"):
            out.append(s[len("name:"):].strip().strip('"').strip("'"))
            continue
        if s.startswith("#"):
            ss = s.lstrip("#").strip()
            if ss:
                out.append(ss)
            continue
        if s.startswith("on:"):
            break
        if s.startswith("-") and "push" in s:
            break
        out.append(s)
        if len(out) >= n + 1:
            break
    return " · ".join(out)[:240]

T = {
    "en": {
        "title": "CI workflows",
        "tldr_tpl": "All {n} GitHub Actions workflows + custom actions.",
        "header": "## Workflows",
        "header_row": "| File | Purpose (from header) |",
        "header_sep": "|------|------------------------|",
        "custom": "## Custom actions",
        "custom_row": "| File | Purpose (from header) |",
        "custom_sep": "|------|------------------------|",
        "intro": f'<span class="gen-badge">auto-gen</span> Generated {datetime.date.today().isoformat()} from `.github/workflows/*.yml`.',
        "note": "> GitHub Actions runs on every push and PR. The `site-build.yml` workflow is the one that deploys this site to GitHub Pages; `site-preview.yml` builds a per-PR preview.",
        "secrets": "## Required secrets (for full CI)",
        "secrets_intro": "| Secret | Used by | Why |",
        "secrets_sep": "|--------|---------|-----|",
        "secrets_row1": "| `CACHIX_SIGNING_KEY` | `cachix-action` | Push built closures to the Cachix cache |",
        "secrets_note": "> Most workflows do not need any secret. The site-build workflow uses `actions/deploy-pages@v4` with the default `GITHUB_TOKEN`, which is provided automatically for public repos.",
        "preview_lang": "lang",
    },
    "ru": {
        "title": "CI-workflow",
        "tldr_tpl": "Все {n} GitHub Actions workflow + кастомные actions.",
        "header": "## Workflows",
        "header_row": "| Файл | Назначение (из шапки) |",
        "header_sep": "|------|----------------------|",
        "custom": "## Кастомные actions",
        "custom_row": "| Файл | Назначение (из шапки) |",
        "custom_sep": "|------|----------------------|",
        "intro": f'<span class="gen-badge">auto-gen</span> Сгенерировано {datetime.date.today().isoformat()} из `.github/workflows/*.yml`.',
        "note": "> GitHub Actions запускается на каждом push и PR. `site-build.yml` — это workflow, который деплоит этот сайт на GitHub Pages; `site-preview.yml` собирает preview для каждого PR.",
        "secrets": "## Требуемые секреты (для полного CI)",
        "secrets_intro": "| Секрет | Используется | Зачем |",
        "secrets_sep": "|--------|--------------|-------|",
        "secrets_row1": "| `CACHIX_SIGNING_KEY` | `cachix-action` | Push собранных closure'ов в Cachix-кеш |",
        "secrets_note": "> Большинству workflow'ов секреты не нужны. site-build workflow использует `actions/deploy-pages@v4` со стандартным `GITHUB_TOKEN`, который выдаётся автоматически для публичных репозиториев.",
    },
}

def main():
    wfs = sorted(WF.glob("*.yml")) + sorted(WF.glob("*.yaml"))
    for lang in ("en", "ru"):
        L = []
        t = T[lang]
        L.append("+++")
        L.append(f'title = "{t["title"]}"')
        L.append('sort_by = "weight"')
        L.append('template = "page.html"')
        L.append("")
        L.append("[extra]")
        L.append(f'tldr = "{t["tldr_tpl"].format(n=len(wfs))}"')
        L.append("+++")
        L.append("")
        L.append(f"# {t['title']}")
        L.append("")
        L.append(t["intro"])
        L.append("")
        L.append(t["note"])
        L.append("")
        L.append(t["header"])
        L.append("")
        L.append(t["header_row"])
        L.append(t["header_sep"])
        for f in wfs:
            L.append(f"| `.github/workflows/{f.name}` | {first_meaningful(f)} |")
        L.append("")

        if ACTIONS.exists():
            acts = sorted(p for p in ACTIONS.rglob("*") if p.is_file())
            if acts:
                L.append(t["custom"])
                L.append("")
                L.append(t["custom_row"])
                L.append(t["custom_sep"])
                for f in acts:
                    L.append(f"| `{f.relative_to(REPO)}` | {first_meaningful(f)} |")
                L.append("")

        L.append("---")
        L.append("")
        L.append(t["secrets"])
        L.append("")
        L.append(t["secrets_intro"])
        L.append(t["secrets_sep"])
        L.append(t["secrets_row1"])
        L.append("")
        L.append(t["secrets_note"])
        L.append("")

        out = SITE / lang / "reference" / "ci.md"
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text("\n".join(L))
        print(f"wrote {out} ({len(wfs)} workflows, {lang})")

if __name__ == "__main__":
    main()
