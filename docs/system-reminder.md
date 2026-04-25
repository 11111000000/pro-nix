% System Reminder — Развёртываемая архитектура и дорожная карта (Build Mode)

Режим: build — документ и план обновлены для практической реализации расширяемой и безопасной фабрики агентов на NixOS.

Краткое назначение
------------------
Построить воспроизводимую локальную платформу, где агенты (код‑ассистенты, автогенераторы патчей, long‑running исполнители) интегрируются в developer workflow. Цель — дать минимальный надёжный контур для автономии, который прирастает расширениями без рефакторинга.

Общее правило (Дао простой архитектуры)
-------------------------------------
- Начинаем с минимального замкнутого контура: Coordinator → Queue → Worker → Model‑Client → Transcript.
- Закрепляем контракт (SURFACE/HOLO) и smoke‑proofs для каждой публичной опции.
- Расширяем строго через определённые точки расширения (adapter points): model‑client API, coordinator API, retrieval API, worker hooks.

1) Минимальная архитектура (Must‑Have)
-------------------------------------
Эта часть обязательна для начала — если её нет, автономия невозможна.

- Model‑Client (Gateway)
  - Что: тонкий HTTP‑прокси, один endpoint `/v1/predict`, `/health`.
  - Зачем: централизует ключи, rate‑limit, mock‑режим, логирование.
  - Развёртывание: NixOS module (nixos/modules/agents-model-client.nix) + derivation `apps.model-client`.

- Coordinator (Task API)
  - Что: простой HTTP API для постановки задач: `POST /tasks` (payload с задачей, optional goal/test spec).
  - Зачем: имеет single entrypoint для автоматов и интеграций (hooks, webhooks, CLI).
  - Развёртывание: derivation `apps.coordinator` и системой unit (nixos/modules/agents-control.nix).

- Worker (Executor)
  - Что: выполняет одну задачу; гарантированно пишет transcript; использует model‑client для LLM вызовов; может запускать тесты/линтеры локально.
  - Зачем: изолированное исполнение, простая логика retry и snapshot результата.
  - Развёртывание: derivation `apps.worker` + systemd template `agents-worker@.service`.

- Persistent artifacts & queue
  - По умолчанию: sqlite local queue + transcripts в `~/.local/state/agents/transcripts/`.
  - При росте: переключение на Redis (опция в agents-control.nix).

- Secrets & resource limits
  - Secrets: sops‑nix/age или operator‑managed `/etc/agents/*.env` (mode 600) — строго не в репо.
  - Limits: systemd slice `agents.slice` (MemoryMax, CPUQuota, IOWeight).

2) Что можно отложить (Later)
------------------------------
- Retrieval (sqlitevec/chroma‑lite/qdrant) — для RAG; plug‑in для worker.
- Redis / durable broker — при многопоточности / масштабировании.
- Podman/generic container images для workers — sandboxing on demand.
- Prometheus/Grafana/Tracing — observability после роста нагрузки.
- Temporal/Argo — durable orchestration при необходимости transactional workflows.

3) От чего можно отказаться (Never now / optional)
------------------------------------------------
- Локальный heavy model serving (GPU inference) — пока не нужно, остаётся external.
- Early migration to k8s / k3s — лишняя операционная сложность на ноутбуке.

4) Adapter points — где расширять спокойно
-----------------------------------------
- Model‑Client API: /v1/predict, /health — stable contract.
- Coordinator API: POST /tasks, GET /tasks/:id — control plane contract.
- Worker hooks: pre_retrieval, post_model, tool_adapters — места для подключения LangChain/other agents.
- Retrieval API: upsert/query for RAG.

5) План превращения в рабочую схему (пошагово, с проверками)
-----------------------------------------------------------

Phase A — Stabilise core (0.5–2 days)
  1. Ensure `nix run .#model-client`, `nix run .#coordinator`, `nix run .#worker` reproducible — smoke run.
     - Проверка: `./tests/scenario/controlplane_e2e.sh` должен завершиться и создать transcript.
  2. Document env vars and add example `/etc/agents/model-client.env.example` (not secret).

Phase B — Declarative deploy (1 day)
  1. Place derivations into flake outputs (done) and replace placeholders in nixos modules with real store paths or wrappers.
  2. Operator enables modules in host flake and runs `nixos-rebuild switch`.
     - Проверка: `systemctl status agents-*` и health endpoints.

Phase C — Safety & policy (0.5 day)
  1. Introduce sops‑nix example and docs/operators/agents-setup.md with steps for secret provisioning.
  2. Tune `agents.slice` defaults for target hardware.

Phase D — Optional scale features (1–3 days each)
  1. Add Redis option and test multi‑worker mode.
  2. Add retrieval service and integrate into worker pre‑prompt pipeline.
  3. Add metrics/alerting.

6) Какие задачи можно автоматизировать сразу
-------------------------------------------
- PR/patch generation (high ROI): worker produces diff → transcript → PR draft.
- Test generation and autotest loop: worker generates tests, runs CI or local test runner, iterates until pass (budgeted retries).
- Code review summaries and static analysis triage.
- CI triage (log summarisation, fix suggestions).

7) Long‑running autonome agents — как строить сегодня
----------------------------------------------------
Чтобы агент доделал проект до финала с минимальным human‑in‑the‑loop, нужны дополнительные элементы и дисциплина:

- Формализовать финальные acceptance criteria заранее (спецификация → machine‑readable tests). Без этого автономия невозможна.
- Разбить проект на мелкие проверяемые таски (DAG). Каждый таск имеет ясные входы/выходы и тесты.
- Использовать durable workflow engine, если задачи долгие/многоступенчатые:
  - Temporal (activities + workflows) — production grade, поддерживает retries, signals, compensation.
  - Или Argo Workflows / Kubernetes orchestration если инфраструктура кластера.
- Worker должен поддерживать idempotent экзекуцию и checkpoints (checkpoint state + transcripts).
- Встроить evaluator agent: после каждого значимого шага автоматический прогон тестов; если тесты FAIL — агент пытается исправить; если фикс не возможен — escalate to human.
- Budgeting и safety: лимиты на количество попыток, сетевые вызовы, финансы (API costs).

8) Типовой long‑running flow (пример)
  1. Coordinator создаёт root task: "implement feature X" + test suite.
  2. Orchestrator (Temporal/Coordinator) разбивает работу на subtasks (analyse, implement, test, integrate).
  3. Worker instances выполняют subtasks, используют retrieval, model‑client и tool adapters (git, shell in sandbox).
  4. После каждого subtask runs evaluator: run tests; if passed → next task; else worker tries fix with a limited number of retries.
  5. On persistent failure: create human review ticket with transcript, diffs, and suggested fixes.
  6. On completion of final acceptance tests → auto‑create final PR or merge (policy controlled).

9) Какие механизмы сегодня для long‑running есть (catalog)
------------------------------------------------------
- Temporal: durable workflows, signals, retries, visibility. Best for complex orchestration.
- Ray Serve / Ray AIR: scalable actors / ML pipelines (for heavier parallel compute).
- Argo Workflows: k8s‑native batch orchestration.
- Celery / Redis + supervisor patterns: simple durable tasks (lighter, less featureful).

10) Заключение и next actions
----------------------------
- Сейчас у тебя реализован минимальный рабочий контур; дальше — сделать сервисы reproducible (flake outputs), закрепить секреты (sops‑nix), и по желанию подключить Redis и Retrieval.
- Для long‑running автономии: ключевые требования — machine‑readable acceptance tests, durable workflow engine (Temporal/Argo), evaluator agent and strict safety policies.

Следующий шаг, который я выполню автоматически: перенести runtime артефакты (apps и nixos modules) в отдельный flake `~/pro-agent` (agent-factory), при этом pro-nix остаётся самодостаточным.

Важно: pro-agent — отдельный проект. Его наличие опционально: pro-nix можно развёртывать и использовать без pro-agent. Связь между ними делается вручную оператором (через flake input path или git URL) и не является жёсткой зависимостью.

Дальнейшие действия после переноса:
- Опубликовать pro-agent в git при желании, настроить CI и кеш (cachix), документировать процесс обновления flake.lock в pro-nix.

If the above passes, Phase A is complete. Then we can evaluate Phase B additions.
