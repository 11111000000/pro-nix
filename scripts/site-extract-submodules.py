#!/usr/bin/env python3
"""Extract .gitmodules + each submodule's README first lines.
   Writes site/content/{en,ru}/reference/submodules.md."""
import pathlib
import re
import datetime

REPO = pathlib.Path(__file__).resolve().parent.parent
GITMODULES = REPO / ".gitmodules"
SUBDIR = REPO / "submodules"
SITE = REPO / "site" / "content"

T = {
    "en": {
        "title": "Submodules",
        "tldr_tpl": "All {n} git submodules. Each is an upstream Emacs package the repo depends on.",
        "intro": '<span class="gen-badge">auto-gen</span> Generated {date} from `.gitmodules` and the submodule READMEs.',
        "policy": '> All submodules are configured for **HTTPS** in `.gitmodules` by default. To switch to SSH for write access, run `just submodules-ssh` (see [Workflow → submodules](@/workflow/submodules.md)).',
        "header": "| Name | Path | URL | Branch | One-line description |",
        "sep": "|------|------|-----|--------|----------------------|",
    },
    "ru": {
        "title": "Сабмодули",
        "tldr_tpl": "Все {n} git-сабмодулей. Каждый — это upstream Emacs-пакет, от которого зависит репо.",
        "intro": '<span class="gen-badge">auto-gen</span> Сгенерировано {date} из `.gitmodules` и README сабмодулей.',
        "policy": '> Все сабмодули настроены на **HTTPS** в `.gitmodules` по умолчанию. Чтобы переключиться на SSH для write-доступа, запустите `just submodules-ssh` (см. [Рабочий процесс → сабмодули](@/workflow/submodules.md)).',
        "header": "| Имя | Путь | URL | Ветка | Описание одной строкой |",
        "sep": "|------|------|-----|--------|----------------------|",
    },
}

def main():
    sections = []
    if GITMODULES.exists():
        text = GITMODULES.read_text()
        for block in text.split("[submodule "):
            block = block.strip()
            if not block:
                continue
            name_m = re.match(r'"([^"]+)"\]', block)
            if not name_m:
                continue
            name = name_m.group(1)
            url = re.search(r"url\s*=\s*(\S+)", block)
            branch = re.search(r"branch\s*=\s*(\S+)", block)
            path_m = re.search(r"path\s*=\s*(\S+)", block)
            url_v = url.group(1) if url else ""
            branch_v = branch.group(1) if branch else ""
            path_v = path_m.group(1) if path_m else name
            sub_path = REPO / path_v
            desc = ""
            for fname in ("README.org", "README.md", "README", "readme.md"):
                p = sub_path / fname
                if p.exists():
                    txt = p.read_text(errors="replace")
                    lines = []
                    for line in txt.splitlines():
                        s = line.strip()
                        if not s:
                            continue
                        if s.startswith("#+") or s.startswith("<!--") or s.startswith("==="):
                            continue
                        if s.startswith("!["): continue
                        if s.startswith("[![") and s.endswith(")"): continue
                        if s.startswith("# "): s = s[2:].strip()
                        if s.startswith("## "): continue
                        lines.append(s)
                        if sum(len(x) for x in lines) > 320:
                            break
                    desc = " ".join(lines)[:320]
                    break
            if not desc:
                desc = "(no README found)"
            sections.append({
                "name": name, "url": url_v, "branch": branch_v, "path": path_v,
                "desc": desc,
            })

    for lang in ("en", "ru"):
        L = []
        t = T[lang]
        L.append("+++")
        L.append(f'title = "{t["title"]}"')
        L.append('sort_by = "weight"')
        L.append('template = "page.html"')
        L.append("")
        L.append("[extra]")
        L.append(f'tldr = "{t["tldr_tpl"].format(n=len(sections))}"')
        L.append("+++")
        L.append("")
        L.append(f"# {t['title']}")
        L.append("")
        L.append(t["intro"].format(date=datetime.date.today().isoformat()))
        L.append("")
        L.append(t["policy"])
        L.append("")
        L.append(t["header"])
        L.append(t["sep"])
        for s in sections:
            url_short = re.sub(r'https?://(www\.)?', '', s["url"])
            branch = s["branch"] or ("(default)" if lang == "en" else "(default)")
            L.append(f"| `{s['name']}` | `{s['path']}` | {url_short} | {branch} | {s['desc']} |")
        L.append("")

        # Architecture note (en/ru)
        if lang == "ru":
            L.append("---")
            L.append("")
            L.append("## Как сабмодули подключаются в Nix")
            L.append("")
            L.append("`nix/emacs-recipes/*.nix` собирают каждый сабмодуль в `emacsPackages`-деривацию. Рецепты лежат в `nix/emacs-recipes/` и подтягиваются overlay'ом `nix/overlays/emacs-extra.nix`.")
            L.append("")
            L.append("Некоторые сабмодули — **форкнутые** для pro-nix (например, `agent-shell`, `agent-shell-hud`, `shaoline`, `tao-theme`); upstream-URL'ы в таблице выше указывают на репозиторий форка.")
            L.append("")
        else:
            L.append("---")
            L.append("")
            L.append("## How submodules are wired into Nix")
            L.append("")
            L.append("`nix/emacs-recipes/*.nix` build each submodule into an `emacsPackages` derivation. The recipe files live in `nix/emacs-recipes/` and are pulled together by `nix/overlays/emacs-extra.nix`.")
            L.append("")
            L.append("Some submodules are **forked** for the pro-nix project (e.g. `agent-shell`, `agent-shell-hud`, `shaoline`, `tao-theme`); the upstream URLs in the table above point to the fork's repository.")
            L.append("")

        out = SITE / lang / "reference" / "submodules.md"
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text("\n".join(L))
        print(f"wrote {out} ({len(sections)} submodules)")

if __name__ == "__main__":
    main()
