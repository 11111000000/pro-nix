---
name: emacs-ellama
description: Ellama — Emacs client for local (Ollama) and cloud LLMs. AGENTS.md-aware, sessions, DLP, skills, plan-and-act loops. Use when a task requires running an LLM directly from Emacs (summarize buffer, code-review region, manage chat sessions) without going through an external MCP client.
---

# Ellama — Emacs-native LLM client

Ellama (<https://github.com/s-kostyaev/ellama>, 948+ stars, v1.29.0, GPL-3) — Emacs client для локальных (Ollama) и облачных (OpenAI-compatible, OpenAI, Claude, Gemini, DeepSeek, OpenRouter, …) LLM. Использует пакет `llm` (GNU ELPA) как абстракцию провайдеров.

## 1. Что умеет Ellama в контексте pro-nix

- **AGENTS.md awareness**: модуль `pro-ai-ellama.el` ищет `AGENTS.md` вверх по дереву от `default-directory` и автоматически добавляет в context каждой сессии.
- **Skills**: reuses skills из `local-templates/{pi,opencode}/skills/` (те же, что используются pi и opencode).
- **Sessions**: persistent sessions на диске; можно переключаться, переименовывать, компактить.
- **Plan-and-act loop**: `M-x pro-ai-ellama-plan-and-act` запускает `ellama-plan-and-act` — агент-цикл с автоматическим продолжением.
- **DLP**: по умолчанию `ellama-tools-dlp-mode 'enforce` + `ellama-tools-irreversible-default-action 'block`.
- **Confirmations**: по умолчанию `ask`-режим (см. `pro-ai-ellama-confirmations`).

## 2. Когда использовать Ellama (vs emcp + внешний LLM)

| Сценарий | Лучший выбор |
|----------|--------------|
| Summarize / code-review / proof-read буфера в Emacs | Ellama |
| Длинная сессия с историей, context-менеджментом | Ellama (persistent sessions) |
| Многошаговый агент (plan + act) внутри Emacs | Ellama (`pro-ai-ellama-plan-and-act`) |
| Задача требует **записи** файлов / eval elisp | emcp + opencode |
| Задача требует MCP-тулзов (chrome-devtools, etc.) | opencode (прямые MCP-тулзы) |
| One-shot completion кода | `ellama-complete` |
| Translate region / buffer | `ellama-translate` / `ellama-translate-buffer` |

## 3. Команды (без биндингов)

`M-x pro-ai-ellama-open` — открыть Ellama chat (transient-меню). Остальные команды: `pro-ai-ellama-summarize`, `pro-ai-ellama-code-review`, `pro-ai-ellama-plan-and-act`, `pro-ai-ellama-list-sessions`, `pro-ai-ellama-load-agents-md`. Полный список — в `emacs/base/modules/pro-ai-ellama.el`.

## 4. Конфигурация

Группа `pro-ai-ellama` (`M-x customize-group RET pro-ai-ellama RET`). Ключевые опции:

- `pro-ai-ellama-confirmations` (t) — `ask`-режим. `nil` = `ellama-tools-allow-all`.
- `pro-ai-ellama-load-agents-md` (t) — авто-загрузка AGENTS.md.
- `pro-ai-ellama-agentic-profile` (`default`) — `default` / `autonomous` / `nil`.
- `pro-ai-ellama-skill-dirs` — каталоги skills (по умолчанию `local-templates/{pi,opencode}/skills/`).

## 5. Provider setup

Ellama использует пакет `llm` (ahyatt/llm). Пример для Ollama:

```elisp
(require 'llm-ollama)
(setopt ellama-provider
        (make-llm-ollama
         :chat-model "qwen3.6:35b"
         :embedding-model "nomic-embed-text"))
```

`~/.authinfo` для секретов:

```
machine api.openai.com login openai password sk-...
machine api.anthropic.com login claude password sk-ant-...
```

## 6. Документация

- Upstream: <https://github.com/s-kostyaev/ellama> (948+ stars)
- README: <https://github.com/s-kostyaev/ellama/blob/master/README.org>
- Внутренний модуль: `emacs/base/modules/pro-ai-ellama.el`
- Nix recipe: `nix/emacs-recipes/ellama.nix`
