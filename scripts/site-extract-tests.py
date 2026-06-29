#!/usr/bin/env python3
"""List the test suite (tests/) into a Zola reference page (both languages)."""
import pathlib
import re
import datetime

REPO = pathlib.Path(__file__).resolve().parent.parent
TESTS = REPO / "tests"
SITE  = REPO / "site" / "content"

T = {
    "en": {
        "title": "Tests",
        "tldr": "Five test layers: VM (slow, gated), contract, unit, scenario, GUI. The whole pyramid runs in <60 s on a normal CI runner.",
        "what_5": "Five test layers. The first two (`flake check` and the unit tests) run on every PR. The rest are gated by `PRO_NIX_RUN_SLOW_CHECKS=1` or by being explicitly invoked through `just`.",
    },
    "ru": {
        "title": "Тесты",
        "tldr": "Пять слоёв тестов: VM (slow, gated), contract, unit, scenario, GUI. Вся пирамида прогоняется за <60 с на обычном CI-раннере.",
        "what_5": "Пять слоёв тестов. Первые два (`flake check` и unit-тесты) запускаются на каждом PR. Остальные — gated by `PRO_NIX_RUN_SLOW_CHECKS=1` или явным вызовом через `just`.",
    },
}

def first_meaningful(path, n=3):
    out = []
    for line in path.read_text(errors="replace").splitlines():
        s = line.strip()
        if not s:
            continue
        if s.startswith("#!"):
            continue
        if s.startswith("#"):
            ss = s.lstrip("#").strip()
            if ss:
                out.append(ss)
            continue
        if s.startswith(";;;"):
            out.append(s.lstrip(";").strip())
            continue
        if s.startswith(";"):
            continue
        out.append(s)
        if len(out) >= n + 1:
            break
    return " / ".join(out)[:240]

def main():
    groups = {
        "VM tests (slow, gated by PRO_NIX_RUN_SLOW_CHECKS=1)": sorted((TESTS / "vm").glob("*")),
        "Contract tests": sorted((TESTS / "contract").glob("*")),
        "Unit tests (tests/contract/unit)": sorted((TESTS / "contract" / "unit").glob("*")),
        "Scenario tests": sorted((TESTS / "scenario").glob("*")),
        "GUI tests (Xvfb)": sorted((TESTS / "gui").glob("*")),
    }
    group_ru = {
        "VM-тесты (slow, gated by PRO_NIX_RUN_SLOW_CHECKS=1)": groups["VM tests (slow, gated by PRO_NIX_RUN_SLOW_CHECKS=1)"],
        "Contract-тесты": groups["Contract tests"],
        "Unit-тесты (tests/contract/unit)": groups["Unit tests (tests/contract/unit)"],
        "Scenario-тесты": groups["Scenario tests"],
        "GUI-тесты (Xvfb)": groups["GUI tests (Xvfb)"],
    }
    header = "| File | What it asserts (from header) |" if False else None
    file_label = "File"
    desc_label = "What it asserts (from header)"

    for lang in ("en", "ru"):
        L = []
        t = T[lang]
        L.append("+++")
        L.append(f'title = "{t["title"]}"')
        L.append('sort_by = "weight"')
        L.append('template = "page.html"')
        L.append("")
        L.append("[extra]")
        L.append(f'tldr = "{t["tldr"]}"')
        L.append("+++")
        L.append("")
        L.append(f"# {t['title']}")
        L.append("")
        L.append(f'<span class="gen-badge">auto-gen</span> Generated {datetime.date.today().isoformat()} from `tests/`.')
        L.append("")
        L.append(f"> {t['what_5']}")
        L.append("")

        cols = ("| File | What it asserts (from header) |",
                "|------|--------------------------------|") if lang == "en" else \
               ("| Файл | Что проверяет (из шапки) |",
                "|------|---------------------------|")
        for label, files in (group_ru if lang == "ru" else groups).items():
            if not files:
                continue
            L.append(f"## {label}")
            L.append("")
            L.append(cols[0])
            L.append(cols[1])
            for f in files:
                if f.is_dir():
                    continue
                desc = first_meaningful(f, 3)
                L.append(f"| `{f.relative_to(REPO)}` | {desc} |")
            L.append("")

        if lang == "en":
            L.append("---")
            L.append("")
            L.append("## How tests are run")
            L.append("")
            L.append("```bash")
            L.append("nix flake check                                   # syntax + checks (fast)")
            L.append("PRO_NIX_RUN_SLOW_CHECKS=1 nix flake check         # + VM tests")
            L.append("just network-contract                             # contract test for the network layer")
            L.append("just headless-tests                               # Emacs ERT, headless")
            L.append("tools/holo-verify.sh unit                         # all 10 unit tests")
            L.append("tools/holo-verify.sh nixos-fast                   # unit + check-nixos-build + verify-units")
            L.append("```")
            L.append("")
        else:
            L.append("---")
            L.append("")
            L.append("## Как запускать тесты")
            L.append("")
            L.append("```bash")
            L.append("nix flake check                                   # синтаксис + checks (быстрый)")
            L.append("PRO_NIX_RUN_SLOW_CHECKS=1 nix flake check         # + VM-тесты")
            L.append("just network-contract                             # contract-тест для сетевого слоя")
            L.append("just headless-tests                               # Emacs ERT, headless")
            L.append("tools/holo-verify.sh unit                         # все 10 unit-тестов")
            L.append("tools/holo-verify.sh nixos-fast                   # unit + check-nixos-build + verify-units")
            L.append("```")
            L.append("")

        out = SITE / lang / "reference" / "tests.md"
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text("\n".join(L))
        print(f"wrote {out} ({lang})")

if __name__ == "__main__":
    main()
