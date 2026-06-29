#!/usr/bin/env python3
"""Extract emacs-keys.org table and write a Zola-compatible Markdown file
   to site/content/{en,ru}/reference/keys.md. Idempotent.
   Generates both languages from a single source.
"""
import re
import pathlib
import datetime

REPO = pathlib.Path(__file__).resolve().parent.parent
SRC  = REPO / "emacs-keys.org"
SITE = REPO / "site" / "content"

def parse_org_table(text):
    """Return list of (section, key, command, description) tuples."""
    rows = []
    for line in text.splitlines():
        # Strip trailing whitespace
        line = line.rstrip()
        if not line.startswith("|"):
            continue
        # Split on |, but the first and last are empty (the borders)
        cells = line.split("|")
        # Cells: ['', 'a', 'b', 'c', 'd', '']
        if len(cells) < 5:
            continue
        # Strip and remove the leading/trailing empty cells
        inner = [c.strip() for c in cells[1:-1]]
        if len(inner) < 4:
            continue
        a, b, c, d = inner[0], inner[1], inner[2], inner[3]
        # Skip header separator
        if re.match(r"^[-+\s|]+$", a) or re.match(r"^[-+\s|]+$", b):
            continue
        # Skip header row (Секция / Клавиша / Команда / Примечание)
        if a in ("Секция", "Section"):
            continue
        rows.append((a, b, c, d))
    return rows

# Translation map for headings.
T = {
    "en": {
        "title": "Key bindings (emacs-keys.org)",
        "tldr_tpl": "All {n} global key bindings from `emacs-keys.org`, grouped by section. This is the executable source — not documentation.",
        "intro_1": '<span class="gen-badge">auto-gen</span> Generated {date} from `emacs-keys.org`.',
        "important": '> **Important:** `emacs-keys.org` is **executable code**, not documentation. Each row in the source org-table becomes a real `global-set-key` at Emacs startup, parsed by `emacs/base/modules/pro-keys.el`. Edit the source, not this page.',
        "stats": "**Total bindings:** {n}  ·  **Sections:** {s}",
        "section_index": "## Section index",
        "header": "| Key | Command | Description |",
        "sep": "|-----|---------|-------------|",
        "how_title": "## How bindings are loaded",
        "how_1": "1. `emacs/base/site-init.el` calls `pro-keys-reload` (in `emacs/base/modules/pro-keys.el`).",
        "how_2": "2. `pro-keys-reload` parses `emacs-keys.org` as an org-table and applies each row as a global binding (or an EXWM-specific binding, or an `org-mode` local binding — the third column is the section name and the parser dispatches accordingly).",
        "how_3": "3. If a binding references a command from a package that is not yet loaded (e.g. `magit-status` from `magit`), the binding is added to `pro-keys-pending-bindings` and re-applied when the package becomes available.",
        "how_4": "4. User overrides live in `~/.config/emacs/keys.org` (same org-table format). If both files exist, both are parsed in order; user wins on conflict.",
        "add_title": "## Adding a binding",
        "add_body": 'Edit `emacs-keys.org` directly — add a row in the appropriate section. Save the file. Inside Emacs, `M-x pro-keys-reload` (or `C-c k`). That\'s it. No `global-set-key` in code, no `use-package` `:bind` block needed.',
    },
    "ru": {
        "title": "Клавиши (emacs-keys.org)",
        "tldr_tpl": "Все {n} глобальных клавиш из `emacs-keys.org`, сгруппированных по секциям. Это исполняемый source — не документация.",
        "intro_1": '<span class="gen-badge">auto-gen</span> Сгенерировано {date} из `emacs-keys.org`.',
        "important": '> **Важно:** `emacs-keys.org` — это **исполняемый код**, не документация. Каждая строка в source-таблице становится реальным `global-set-key` при старте Emacs, парсится `emacs/base/modules/pro-keys.el`. Редактируйте source, а не эту страницу.',
        "stats": "**Всего биндингов:** {n}  ·  **Секций:** {s}",
        "section_index": "## Указатель секций",
        "header": "| Клавиша | Команда | Описание |",
        "sep": "|-----|---------|----------|",
        "how_title": "## Как загружаются биндинги",
        "how_1": "1. `emacs/base/site-init.el` вызывает `pro-keys-reload` (в `emacs/base/modules/pro-keys.el`).",
        "how_2": "2. `pro-keys-reload` парсит `emacs-keys.org` как org-таблицу и применяет каждую строку как глобальный биндинг (или EXWM-специфичный, или `org-mode` локальный — третий столбец это имя секции, и парсер диспатчит соответственно).",
        "how_3": "3. Если биндинг ссылается на команду из пакета, ещё не загруженного (например, `magit-status` из `magit`), биндинг добавляется в `pro-keys-pending-bindings` и пере-применяется, когда пакет становится доступен.",
        "how_4": "4. Пользовательские override'ы лежат в `~/.config/emacs/keys.org` (тот же формат org-таблицы). Если оба файла существуют, оба парсятся по порядку; пользователь выигрывает на конфликте.",
        "add_title": "## Добавление биндинга",
        "add_body": 'Отредактируйте `emacs-keys.org` напрямую — добавьте строку в нужную секцию. Сохраните файл. Внутри Emacs `M-x pro-keys-reload` (или `C-c k`). Всё. Никаких `global-set-key` в коде, никаких `use-package` `:bind` блоков не нужно.',
    },
}

def render(lang, rows):
    L = []
    t = T[lang]
    L.append("+++")
    L.append(f'title = "{t["title"]}"')
    L.append('sort_by = "weight"')
    L.append('template = "page.html"')
    L.append("")
    L.append("[extra]")
    L.append(f'tldr = "{t["tldr_tpl"].format(n=len(rows), s=len(set(r[0] for r in rows)))}"')
    L.append("+++")
    L.append("")
    L.append(f"# {t['title']}")
    L.append("")
    L.append(t["intro_1"].format(date=datetime.date.today().isoformat()))
    L.append("")
    L.append(t["important"])
    L.append("")
    L.append(t["stats"].format(n=len(rows), s=len(set(r[0] for r in rows))))
    L.append("")
    L.append(t["section_index"])
    L.append("")

    by_section = {}
    for sec, key, cmd, desc in rows:
        by_section.setdefault(sec, []).append((key, cmd, desc))

    for s in sorted(by_section):
        anchor = re.sub(r'[^a-z0-9-]+', '-', s.lower())
        L.append(f"* [{s}](#{anchor}) — {len(by_section[s])}")
    L.append("")
    L.append("---")
    L.append("")

    for s in sorted(by_section):
        anchor = re.sub(r'[^a-z0-9-]+', '-', s.lower())
        L.append(f"## {s} {{ #{anchor} }}")
        L.append("")
        L.append(t["header"])
        L.append(t["sep"])
        for k, c, d in by_section[s]:
            L.append(f"| `{k}` | `{c}` | {d} |")
        L.append("")

    L.append("---")
    L.append("")
    L.append(t["how_title"])
    L.append("")
    L.append(t["how_1"])
    L.append(t["how_2"])
    L.append(t["how_3"])
    L.append(t["how_4"])
    L.append("")
    L.append(t["add_title"])
    L.append("")
    L.append(t["add_body"])
    L.append("")
    return "\n".join(L)

def main():
    rows = parse_org_table(SRC.read_text())
    for lang in ("en", "ru"):
        out = SITE / lang / "reference" / "keys.md"
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(render(lang, rows))
        print(f"wrote {out} ({len(rows)} bindings)")

if __name__ == "__main__":
    main()
