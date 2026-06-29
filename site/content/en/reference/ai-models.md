+++
title = "AI models"
sort_by = "weight"
template = "page.html"

[extra]
tldr = "3 AI providers, 31 models, all routed through gptel."
+++

# AI models

<span class="gen-badge">auto-gen</span> Generated 2026-06-16 from `emacs/base/modules/ai-models.json`.

> This file is the **base** catalogue. The user can drop a custom `ai-models.json` in `~/.config/emacs/` to override; `pro-ai.el` merges the two with the user file winning on conflict (`pro-ai--merge-provider-configs`).

## aitunnel

* **Host:** `api.aitunnel.ru`
* **Endpoint:** `/v1/chat/completions`
* **Auth:** `token` on `api.aitunnel.ru`
* **Preferred model:** `gpt-5.4-mini`
* **Models (11):**
  * `gpt-5.4-mini` ← preferred
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

* **Host:** `openrouter.ai`
* **Endpoint:** `/api/v1/chat/completions`
* **Auth:** `token` on `openrouter.ai`
* **Preferred model:** `qwen/qwen3-next-80b-a3b-instruct:free`
* **Models (11):**
  * `qwen/qwen3-next-80b-a3b-instruct:free` ← preferred
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

* **Host:** `api.siliconflow.com`
* **Endpoint:** `/v1/chat/completions`
* **Auth:** `token` on `api.siliconflow.com`
* **Preferred model:** `Qwen/Qwen3-235B-A22B-2507`
* **Models (9):**
  * `Qwen/Qwen3-235B-A22B-2507` ← preferred
  * `Qwen/Qwen3-Coder`
  * `Qwen/Qwen3-30B-A3B`
  * `DeepSeek-ai/DeepSeek-V3`
  * `DeepSeek-ai/DeepSeek-R1`
  * `deepseek-ai/DeepSeek-R1-Distill-Qwen-32B`
  * `GLM-4.7-Flash`
  * `glm-4-9b-chat`
  * `Qwen/Qwen3-8B`

---

## How the catalogue reaches Emacs

1. `emacs/base/modules/ai-models.json` is the file you're reading.
2. `pro-ai.el` reads it via `json-read-file` (via `pro-ai--read-json-file`).
3. Each provider becomes a `gptel-backend` through `pro-ai--register-backends`.
4. `pro-ai-backend` (default `'aitunnel`) chooses the active one; the model is selected in the gptel transient UI (`M-x pro-ai-open-entry` → `C-c a`).

## The other catalogue: `local-templates/pi/models.json`

The `pi` CLI agent uses a **different** file: `local-templates/pi/models.json`. It is deployed to `~/.pi/agent/models.json` by `pro-agent-configs.nix`. The two catalogues are *kept in sync by hand* today; the goal is for `pro-ai--config` to be the single source and have the `pi` JSON be a projection of it.
