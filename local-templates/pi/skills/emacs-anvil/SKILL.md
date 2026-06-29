---
name: emacs-anvil
description: anvil.el — token-efficient MCP server running inside Emacs. Drives files, org-mode, Elisp & SQLite from any MCP client through Emacs primitives instead of generic sed/grep/Read round-trips. Use when you need to operate on files inside a running Emacs session with high token efficiency, query an org file, run a specific Elisp function, or batch-edit many files atomically.
---

# anvil.el — MCP-server in Emacs

anvil.el — это MCP-сервер, написанный на Elisp и работающий внутри вашего живого Emacs. Он даёт ~40 default tools (`anvil-file-*`, `anvil-org-*`, `anvil-elisp-*`, `anvil-sqlite-*`, `anvil-shell-*`) плюс опциональные модули (memory, orchestrator, semantic, mu4e, cad, fusion). Главная фишка — примитивы работают на **регионах / headings / buffer state**, а не на whole-file Read+Write, что экономит 60-90% токенов на типичных refactor-сценариях.

## 1. Текущее состояние в pro-nix

**Статус: experimental.** Recipe `nix/emacs-recipes/anvil.nix` собирает пакет из upstream (commit `4306ea1`, v1.3.0, 2026-06-26). Модуль `emacs/base/modules/pro-ai-anvil.el` регистрирует публичные команды в Emacs:

- `M-x pro-ai-anvil-server-start` — стартует anvil-enable + anvil-server-start.
- `M-x pro-ai-anvil-server-stop` — останавливает.
- `M-x pro-ai-anvil-server-status` — печатает состояние.
- `M-x pro-ai-anvil-list-tools` — перечисляет активные anvil-* tools.
- `M-x pro-ai-anvil-describe-setup` — печатает JSON-фрагмент для вставки в ваш `mcp.json`.

**StdIO-мост** (функция `pro-ai-anvil--stdio-loop`) **не реализован** в этой версии. Поэтому в `local-templates/{pi,opencode}/` регистрация помечена `_status: experimental`. Активация для pi/opencode — ручная:

1. Запустите Emacs (`emacs --daemon` или обычный).
2. В нём выполните `M-x pro-ai-anvil-server-start`. Сервер стартует на stdio.
3. Подключите свой MCP-клиент через любой `emacsclient --eval` биндинг (см. ниже).

## 2. Альтернатива на сейчас: используйте `emcp`

Пока anvil stdio-bridge не дописан, для file/org/eval операций **используйте `emcp`** (см. skill `emacs-emcp`). `emcp` — стабильный HTTP MCP-сервер в Emacs, всегда доступен по `http://127.0.0.1:38913/mcp` после старта Emacs. Инструменты: `apropos`, `describe`, `find-definition`, `find-references`, `get-variable`, `set-variable`, `screenshot`, `eval`, `send-keys`.

## 3. Когда anvil выигрывает у emcp

| Сценарий | emcp | anvil |
|----------|------|-------|
| Прочитать один heading из org-файла в 13 000 строк | Read+parse вручную | `anvil-org-read-headline` |
| Заменить одну строку в 1.2 MB org-файле | Read 1.2 MB + Edit | `anvil-file-replace-string` |
| 3+ правки в одном файле | 3× Read+Edit | `anvil-file-batch` (atomic, ~70% экономии) |
| Выполнить произвольный elisp | `eval` (ask-режим) | `anvil-elisp-eval` (ask-режим) |
| Структурированная работа с org (headings, properties, tags) | `eval` + ручной sexp | `anvil-org-*` (нативные примитивы) |
| Query SQLite из локальной БД | `eval` shell + sqlite3 | `anvil-sqlite-query` |

**Решающее правило:** если операция работает на целом файле (`read_file` + `edit_file` через emcp) — попробуйте сначала anvil. Если на структурном примитиве (region / heading / batch) — anvil выигрывает по токенам в разы.

## 4. Как подключить, когда stdio-bridge будет готов

После того как `pro-ai-anvil--stdio-loop` будет реализован, registration в `~/.pi/agent/mcp.json` (или `~/.config/opencode/opencode.json`) выглядит так:

```json
{
  "mcpServers": {
    "anvil": {
      "command": "emacsclient",
      "args": ["--eval", "(pro-ai-anvil--stdio-loop)"],
      "directTools": true,
      "lifecycle": "keep-alive"
    }
  }
}
```

Либо — запустите `M-x pro-ai-anvil-describe-setup` в Emacs и скопируйте готовый JSON в kill-ring.

## 5. Документация

- Upstream: <https://github.com/zawatton/anvil.el> (73+ stars, v1.3.0, GPL-3)
- README: <https://github.com/zawatton/anvil.el/blob/master/README.org>
- Сравнение с emcp (token economy): см. раздел *"Efficiency — why Anvil saves AI tokens"* в README.
- Внутренний модуль: `emacs/base/modules/pro-ai-anvil.el`
- Nix recipe: `nix/emacs-recipes/anvil.nix`
