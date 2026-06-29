+++
title = "AI-модели"
sort_by = "weight"
template = "page.html"

[extra]
tldr = "3 AI-провайдеров, 31 моделей, все через gptel."
+++

# AI-модели

<span class="gen-badge">auto-gen</span> Сгенерировано 2026-06-16 из `emacs/base/modules/ai-models.json`.

> Этот файл — **базовый** каталог. Пользователь может положить кастомный `ai-models.json` в `~/.config/emacs/` для override'а; `pro-ai.el` мерджит два файла, причём пользовательский выигрывает на конфликте (`pro-ai--merge-provider-configs`).

## aitunnel

* **Хост:** `api.aitunnel.ru`
* **Endpoint:** `/v1/chat/completions`
* **Auth:** `token` on `api.aitunnel.ru`
* **Предпочитаемая модель:** `gpt-5.4-mini`
* **Модели (11):**
  * `gpt-5.4-mini` ← предпочтительная
  * `gpt-5.4`
  * `gpt-5.2`
  * `gpt-5.2-chat`
  * `qwen3.5-235b-a22b-2507`
  * `qwen3.5-coder`
  * `minimax-m2.7`
  * `claude-sonnet-4.6`
  * `deepseek-v3.2`
  * `gpt-4.1-mini`
  * `gemini-2.5-flash`

## openrouter

* **Хост:** `openrouter.ai`
* **Endpoint:** `/api/v1/chat/completions`
* **Auth:** `token` on `openrouter.ai`
* **Предпочитаемая модель:** `qwen/qwen3-next-80b-a3b-instruct:free`
* **Модели (11):**
  * `qwen/qwen3-next-80b-a3b-instruct:free` ← предпочтительная
  * `qwen/qwen3-coder:free`
  * `qwen/qwen3-30b-a3b:free`
  * `minimax/minimax-m2.5:free`
  * `openai/gpt-oss-120b:free`
  * `nvidia/nemotron-3-super-120b-a12b:free`
  * `z-ai/glm-4.5-air:free`
  * `google/gemma-4-31b-it:free`
  * `google/gemma-4-26b-a4b-it:free`
  * `meta-llama/llama-3.3-70b-instruct:free`
  * `openai/gpt-oss-20b:free`

## siliconflow

* **Хост:** `api.siliconflow.com`
* **Endpoint:** `/v1/chat/completions`
* **Auth:** `token` on `api.siliconflow.com`
* **Предпочитаемая модель:** `Qwen/Qwen3-235B-A22B-2507`
* **Модели (9):**
  * `Qwen/Qwen3-235B-A22B-2507` ← предпочтительная
  * `Qwen/Qwen3-Coder`
  * `Qwen/Qwen3-30B-A3B`
  * `DeepSeek-ai/DeepSeek-V3`
  * `DeepSeek-ai/DeepSeek-R1`
  * `deepseek-ai/DeepSeek-R1-Distill-Qwen-32B`
  * `GLM-4.7-Flash`
  * `glm-4-9b-chat`
  * `Qwen/Qwen3-8B`

---

## Как каталог попадает в Emacs

1. `emacs/base/modules/ai-models.json` — это файл, который вы читаете.
2. `pro-ai.el` читает его через `json-read-file` (через `pro-ai--read-json-file`).
3. Каждый провайдер становится `gptel-backend` через `pro-ai--register-backends`.
4. `pro-ai-backend` (default `'aitunnel`) выбирает активный; модель выбирается в gptel-transient UI (`M-x pro-ai-open-entry` → `C-c a`).

## Другой каталог: `local-templates/pi/models.json`

CLI-агент `pi` использует **другой** файл: `local-templates/pi/models.json`. Он деплоится в `~/.pi/agent/models.json` через `pro-agent-configs.nix`. Два каталога сегодня *синхронизируются вручную*; цель — чтобы `pro-ai--config` был единственным source, а JSON `pi` — его проекция.
