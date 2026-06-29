---
name: emacs-ellama
description: Ellama — Emacs client for local (Ollama) and cloud LLMs. AGENTS.md-aware, sessions, DLP, skills, plan-and-act loops. Use when a task requires running an LLM directly from Emacs (e.g. summarize buffer, code-review region, ask about selection, manage chat sessions) without going through an external MCP client.
---

# Ellama — Emacs-native LLM client

Ellama (<https://github.com/s-kostyaev/ellama>, 948+ stars, v1.29.0, GPL-3) — Emacs client для локальных (Ollama) и облачных (OpenAI-compatible, OpenAI, Claude, Gemini, DeepSeek, OpenRouter, …) LLM. Использует пакет `llm` (GNU ELPA) как абстракцию провайдеров.

## 1. Что умеет Ellama в контексте pro-nix

- **AGENTS.md awareness**: модуль `pro-ai-ellama.el` ищет `AGENTS.md` вверх по дереву от `default-directory` и автоматически добавляет в context каждой сессии.
- **Skills**: reuses skills из `local-templates/{pi,opencode}/skills/` (те же, что используются pi и opencode).
- **Sessions**: persistent sessions на диске; можно переключаться, переименовывать, компактить.
- **Plan-and-act loop**: `M-x pro-ai-ellama-plan-and-act` запускает `ellama-plan-and-act` — агент-цикл с автоматическим продолжением.
- **DLP**: по умолчанию включён `ellama-tools-dlp-mode 'enforce` + `ellama-tools-irreversible-default-action 'block`. См. `defcustom pro-ai-ellama-agentic-profile` в `pro-ai-ellama.el`.
- **Confirmations**: по умолчанию `ask`-режим (см. `pro-ai-ellama-confirmations`). Не выставлено `ellama-tools-allow-all` без явного `pro-ai-ellama-agentic-profile = 'autonomous'`.

## 2. Когда использовать Ellama (vs emcp + внешний LLM)

| Сценарий | Лучший выбор |
|----------|--------------|
| Summarize / code-review / proof-read буфера в Emacs | Ellama (одной командой, прямо в Emacs) |
| Длинная сессия с историей, context-менеджментом | Ellama (persistent sessions) |
| Многошаговый агент (plan + act) внутри Emacs | Ellama (`pro-ai-ellama-plan-and-act`) |
| Задача требует **записи** файлов / eval elisp | emcp + внешний LLM (pi/opencode) |
| Задача требует MCP-тулзов (chrome-devtools, etc.) | emcp + pi/opencode |
| Один-shot completion кода | `ellama-complete` |
| Translate region / buffer | `ellama-translate` / `ellama-translate-buffer` |

## 3. Горячие клавиши (после `M-x pro-keys-reload`)

| Клавиша | Команда | Что делает |
|---------|---------|------------|
| `C-c e e` | `pro-ai-ellama-open` | Открыть Ellama chat (transient-меню) |
| `C-c e s` | `pro-ai-ellama-summarize` | Summarize region/buffer |
| `C-c e r` | `pro-ai-ellama-code-review` | Code-review region/buffer |
| `C-c e p` | `pro-ai-ellama-plan-and-act` | Plan-and-act loop |
| `C-c e l` | `pro-ai-ellama-list-sessions` | Меню сессий (compact/switch/rename) |
| `C-c e a` | `pro-ai-ellama-load-agents-md` | Перечитать AGENTS.md для текущего проекта |

Биндинги регистрируются через `pro-keys` registry (`pro-ai-ellama--register-keys`).

## 4. Конфигурация

Все опции — в группе `pro-ai-ellama` (`M-x customize-group RET pro-ai-ellama RET`).

| Опция | Default | Описание |
|-------|---------|----------|
| `pro-ai-ellama-confirmations` | t | `ask`-режим для tool confirmations. При `nil` — `ellama-tools-allow-all` (опасно). |
| `pro-ai-ellama-load-agents-md` | t | Авто-загрузка инструкций в context. |
| `pro-ai-ellama-agents-md-filenames` | `("AGENTS.md" "CLAUDE.md" "INSTRUCTIONS.md" ".agentrc")` | Список имён файлов (по убыванию приоритета). |
| `pro-ai-ellama-agentic-profile` | `default` | `default` / `autonomous` / `nil`. |
| `pro-ai-ellama-skill-dirs` | (см. defcustom) | Каталоги skills (reuses pi/opencode). |
| `pro-ai-ellama-srt-policy-file` | репозиторийный шаблон | SRT policy для autonomous profile. Скопировать в `~/.config/ellama/`. |

## 5. Shared provider bridge

`C-c e m` (`pro-ai-ellama-use-shared-model`) синхронизирует `ellama-provider`
с активным backend из `pro-ai.el`. Полезно когда gptel и Ellama должны
использовать одну и ту же модель:

1. `pro-ai-toggle-backend` (или customize `pro-ai-backend`) → выбор провайдера.
2. `C-c e m` → ellama подхватывает тот же provider + ключ из authinfo.

Это позволяет Ellama (через `llm` пакет) и gptel (через curl) использовать
один OpenAI-compatible ключ, без дублирования конфигурации.

## 6. Org-babel integration

В `pro-ai-ellama.el` зарегистрирован org-babel язык `ellama`. Использование
внутри Org файла:

```org
#+begin_src ellama :results value
Summarize this Org subtree in one paragraph.
#+end_src

#+RESULTS:
: <summary text from LLM>
```

Код блока передаётся как prompt; результат — string в `:RESULTS`.
Не требует `org-babel-do-load-languages` — функция регистрируется
автоматически через `with-eval-after-load 'org`.

## 7. Ephemeral context

Однократное добавление файлов/директорий в context для одного запроса
(не persistent — отличие от `load-agents-md`).

| Биндинг | Команда | Что делает |
|----------|---------|------------|
| `C-c e b` | `pro-ai-ellama-add-buffer-as-context` | Сохранить buffer → /tmp файл → ephemeral |
| `C-c e r` | `pro-ai-ellama-add-region-as-context` | Сохранить region → /tmp файл → ephemeral |

Программно (для кастомных сценариев):
- `(pro-ai-ellama--add-ephemeral-file "path/to/file.el")`
- `(pro-ai-ellama--add-ephemeral-directory "path/to/dir/")`
- `(pro-ai-ellama--add-ephemeral-image "path/to/image.png")`

## 8. Provider setup

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

Параметры через `~/.authinfo` (см. `pro-ai--load-key-from-authinfo` в `pro-ai.el`):

```
machine api.openai.com login openai password sk-...
machine api.anthropic.com login claude password sk-ant-...
machine localhost login ollama password dummy
```

## 6. Документация

- Upstream: <https://github.com/s-kostyaev/ellama> (948+ stars, v1.29.0, GPL-3)
- README: <https://github.com/s-kostyaev/ellama/blob/master/README.org>
- Внутренний модуль: `emacs/base/modules/pro-ai-ellama.el`
- Nix recipe: `nix/emacs-recipes/ellama.nix`
- Skill-loader: `ellama-skills.el` (upstream)
- Смежный модуль: `pro-ai.el` (gptel-стек, аналогичная регистрация)
