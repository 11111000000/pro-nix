---
name: emacs-anvil
description: anvil.el — token-efficient MCP server running inside Emacs. Drives files, org-mode, Elisp & SQLite from any MCP client through Emacs primitives instead of generic sed/grep/Read round-trips. Use when you need to operate on files inside a running Emacs session with high token efficiency, query an org file, run a specific Elisp function, or batch-edit many files atomically.
---

# anvil.el — MCP-server in Emacs

anvil.el — это MCP-сервер, написанный на Elisp и работающий внутри вашего живого Emacs. Он даёт ~40 default tools (`anvil-file-*`, `anvil-org-*`, `anvil-elisp-*`, `anvil-sqlite-*`, `anvil-shell-*`) плюс опциональные модули (memory, orchestrator, semantic, mu4e, cad, fusion). Главная фишка — примитивы работают на **регионах / headings / buffer state**, а не на whole-file Read+Write, что экономит 60-90% токенов на типичных refactor-сценариях.

## 1. Статус в pro-nix

**experimental.** Recipe `nix/emacs-recipes/anvil.nix` собирает пакет из upstream (commit `4306ea1`, v1.3.0). Модуль `emacs/base/modules/pro-ai-anvil.el` регистрирует команды в Emacs:

- `M-x pro-ai-anvil-server-start` — стартует anvil-enable + anvil-server-start.
- `M-x pro-ai-anvil-server-stop` — останавливает.
- `M-x pro-ai-anvil-server-status` — печатает состояние.
- `M-x pro-ai-anvil-list-tools` — перечисляет активные anvil-* tools.
- `M-x pro-ai-anvil-describe-setup` — печатает JSON-фрагмент для вставки в mcp.json.

**StdIO-мост** (функция `pro-ai-anvil--stdio-loop`) **не реализован** в этой версии. Регистрация в `local-templates/opencode/opencode.json` помечена `_status: experimental`.

## 2. Альтернатива на сейчас: emcp

Используйте `emcp` (skill `emacs-emcp`) для file/org/eval операций. URL: `http://127.0.0.1:38913/mcp`. Tools: `apropos`, `describe`, `find-definition`, `find-references`, `get-variable`, `set-variable`, `screenshot`, `eval`, `send-keys`.

## 3. Когда anvil выигрывает у emcp

| Сценарий | emcp | anvil |
|----------|------|-------|
| Прочитать один heading из org-файла в 13 000 строк | Read+parse вручную | `anvil-org-read-headline` |
| Заменить одну строку в 1.2 MB org-файле | Read 1.2 MB + Edit | `anvil-file-replace-string` |
| 3+ правки в одном файле | 3× Read+Edit | `anvil-file-batch` (atomic, ~70% экономии) |
| Выполнить произвольный elisp | `eval` (ask-режим) | `anvil-elisp-eval` (ask-режим) |
| Структурированная работа с org (headings, properties, tags) | `eval` + ручной sexp | `anvil-org-*` (нативные примитивы) |
| Query SQLite из локальной БД | `eval` shell + sqlite3 | `anvil-sqlite-query` |

**Правило:** целый файл — emcp. Структурный примитив (region / heading / batch) — anvil.

## 4. Как подключить, когда stdio-bridge будет готов

После реализации `pro-ai-anvil--stdio-loop`, registration в `~/.config/opencode/opencode.json`:

```json
{
  "mcp": {
    "anvil": {
      "type": "local",
      "command": ["emacsclient", "--eval", "(pro-ai-anvil--stdio-loop)"],
      "enabled": true
    }
  }
}
```

Либо: `M-x pro-ai-anvil-describe-setup` в Emacs — готовый JSON в kill-ring.

## 5. Документация

- Upstream: <https://github.com/zawatton/anvil.el> (73+ stars, v1.3.0, GPL-3)
- README: <https://github.com/zawatton/anvil.el/blob/master/README.org>
- Внутренний модуль: `emacs/base/modules/pro-ai-anvil.el`
- Nix recipe: `nix/emacs-recipes/anvil.nix`
