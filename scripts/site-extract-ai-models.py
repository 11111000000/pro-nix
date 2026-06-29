#!/usr/bin/env python3
"""Render emacs/base/modules/ai-models.json as a Zola reference page (both langs)."""
import json
import pathlib
import datetime

REPO = pathlib.Path(__file__).resolve().parent.parent
SRC  = REPO / "emacs" / "base" / "modules" / "ai-models.json"
SITE = REPO / "site" / "content"

T = {
    "en": {
        "title": "AI models",
        "tldr_tpl": "{n} AI providers, {m} models, all routed through gptel.",
        "intro": f'<span class="gen-badge">auto-gen</span> Generated {datetime.date.today().isoformat()} from `emacs/base/modules/ai-models.json`.',
        "header": "## AI models",
        "note": "> This file is the **base** catalogue. The user can drop a custom `ai-models.json` in `~/.config/emacs/` to override; `pro-ai.el` merges the two with the user file winning on conflict (`pro-ai--merge-provider-configs`).",
        "field_host": "**Host:**",
        "field_endpoint": "**Endpoint:**",
        "field_auth": "**Auth:**",
        "field_preferred": "**Preferred model:**",
        "field_models": "**Models ({n}):**",
        "preferred_marker": " ← preferred",
        "section": "## AI models",
        "wired_title": "## How the catalogue reaches Emacs",
        "wired_1": "1. `emacs/base/modules/ai-models.json` is the file you're reading.",
        "wired_2": "2. `pro-ai.el` reads it via `json-read-file` (via `pro-ai--read-json-file`).",
        "wired_3": "3. Each provider becomes a `gptel-backend` through `pro-ai--register-backends`.",
        "wired_4": "4. `pro-ai-backend` (default `'aitunnel`) chooses the active one; the model is selected in the gptel transient UI (`M-x pro-ai-open-entry` → `C-c a`).",
        "other_title": "## The other catalogue: `local-templates/pi/models.json`",
        "other_body": "The `pi` CLI agent uses a **different** file: `local-templates/pi/models.json`. It is deployed to `~/.pi/agent/models.json` by `pro-agent-configs.nix`. The two catalogues are *kept in sync by hand* today; the goal is for `pro-ai--config` to be the single source and have the `pi` JSON be a projection of it.",
    },
    "ru": {
        "title": "AI-модели",
        "tldr_tpl": "{n} AI-провайдеров, {m} моделей, все через gptel.",
        "intro": f'<span class="gen-badge">auto-gen</span> Сгенерировано {datetime.date.today().isoformat()} из `emacs/base/modules/ai-models.json`.',
        "header": "## AI-модели",
        "note": "> Этот файл — **базовый** каталог. Пользователь может положить кастомный `ai-models.json` в `~/.config/emacs/` для override'а; `pro-ai.el` мерджит два файла, причём пользовательский выигрывает на конфликте (`pro-ai--merge-provider-configs`).",
        "field_host": "**Хост:**",
        "field_endpoint": "**Endpoint:**",
        "field_auth": "**Auth:**",
        "field_preferred": "**Предпочитаемая модель:**",
        "field_models": "**Модели ({n}):**",
        "preferred_marker": " ← предпочтительная",
        "section": "## AI-модели",
        "wired_title": "## Как каталог попадает в Emacs",
        "wired_1": "1. `emacs/base/modules/ai-models.json` — это файл, который вы читаете.",
        "wired_2": "2. `pro-ai.el` читает его через `json-read-file` (через `pro-ai--read-json-file`).",
        "wired_3": "3. Каждый провайдер становится `gptel-backend` через `pro-ai--register-backends`.",
        "wired_4": "4. `pro-ai-backend` (default `'aitunnel`) выбирает активный; модель выбирается в gptel-transient UI (`M-x pro-ai-open-entry` → `C-c a`).",
        "other_title": "## Другой каталог: `local-templates/pi/models.json`",
        "other_body": "CLI-агент `pi` использует **другой** файл: `local-templates/pi/models.json`. Он деплоится в `~/.pi/agent/models.json` через `pro-agent-configs.nix`. Два каталога сегодня *синхронизируются вручную*; цель — чтобы `pro-ai--config` был единственным source, а JSON `pi` — его проекция.",
    },
}

def main():
    data = json.loads(SRC.read_text())
    providers = data.get("providers", {})
    total = sum(len(p.get("models", [])) for p in providers.values())

    for lang in ("en", "ru"):
        L = []
        t = T[lang]
        L.append("+++")
        L.append(f'title = "{t["title"]}"')
        L.append('sort_by = "weight"')
        L.append('template = "page.html"')
        L.append("")
        L.append("[extra]")
        L.append(f'tldr = "{t["tldr_tpl"].format(n=len(providers), m=total)}"')
        L.append("+++")
        L.append("")
        L.append(f"# {t['title']}")
        L.append("")
        L.append(t["intro"])
        L.append("")
        L.append(t["note"])
        L.append("")

        for name in sorted(providers):
            p = providers[name]
            L.append(f"## {name}")
            L.append("")
            host = p.get("host", "")
            ep = p.get("endpoint", "")
            auth_host = p.get("auth_host", host)
            auth_user = p.get("auth_user", "token")
            preferred = p.get("preferred_model", "")
            models = p.get("models", [])
            L.append(f"* {t['field_host']} `{host}`")
            L.append(f"* {t['field_endpoint']} `{ep}`")
            L.append(f"* {t['field_auth']} `{auth_user}` on `{auth_host}`")
            if preferred:
                L.append(f"* {t['field_preferred']} `{preferred}`")
            L.append(f"* {t['field_models'].format(n=len(models))}")
            for m in models:
                marker = t["preferred_marker"] if m == preferred else ""
                L.append(f"  * `{m}`{marker}")
            L.append("")

        L.append("---")
        L.append("")
        L.append(t["wired_title"])
        L.append("")
        L.append(t["wired_1"])
        L.append(t["wired_2"])
        L.append(t["wired_3"])
        L.append(t["wired_4"])
        L.append("")
        L.append(t["other_title"])
        L.append("")
        L.append(t["other_body"])
        L.append("")

        out = SITE / lang / "reference" / "ai-models.md"
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text("\n".join(L))
        print(f"wrote {out} ({len(providers)} providers, {total} models, {lang})")

if __name__ == "__main__":
    main()
