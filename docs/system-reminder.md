# System Reminder — Minimal Agent Factory Plan (Build Mode)

Operational mode: build. This document updates the previous plan and reduces scope to a minimal, high-leverage implementation for small projects.

Principle
---------
Follow the Dao of minimal effective change: implement the smallest set of components that produce a working end-to-end agent pipeline (submit → execute → result), secure it, and make it reproducible via Nix. Postpone optional components until the core loop proves valuable.

Must-have (Phase A) — Minimal Closed Loop
-----------------------------------------
1. Model Client (proxy)
   - NixOS module: `nixos/modules/agents-model-client.nix` (systemd service)
   - App: FastAPI proxy with `/health` and `/v1/predict`.
   - Secrets via env file or sops-nix; no model files downloaded.

2. Worker
   - Single worker derivation (`apps.worker`) running a simple loop:
     - accept a task (from local queue or coordinator endpoint)
     - call model-client for model results
     - write `transcript.json` in `~/.local/state/agents/transcripts/` or `/var/lib/agents/transcripts`

3. Coordinator (minimal)
   - Minimal HTTP endpoint to `POST /tasks` → store to local sqlite queue or ephemeral file queue for worker to pick up.

4. Secrets & Limits
   - Use `sops-nix`/`age` or operator-provided `/etc/agents/model-client.env` (mode 600).
   - Systemd slice `agents.slice` defaults (MemoryMax=4G, CPUQuota=80%).

5. Smoke tests (Proof)
   - `tests/contract/test_modelclient_smoke.sh` — model-client app exists + basic health check when run in devshell.
   - `tests/scenario/controlplane_e2e.sh` — mocked model-client e2e path: coordinator -> worker -> transcript.

Deferred (Phase B+) — Add only when core loop is solid
----------------------------------------------------
- Retrieval (sqlitevec/chroma-lite) — optional; add as plugin to worker.
- Redis queue (replace sqlite/local queue) — when multi-worker is needed.
- Podman container images for workers — optional for stronger sandboxing.
- Qdrant / vector DB — if retrieval needs scale.
- Observability (Prometheus + Grafana) and tracing.

Files and artifacts this iteration will create
---------------------------------------------
- nixos/modules/agents-model-client.nix (exists)
- apps/model-client/* (exists)
- apps/worker/* (skeleton)
- apps/coordinator/* (skeleton)
- tests/scenario/controlplane_e2e.sh (skeleton)
- docs/operators/agents-setup.md (runbook)

Next concrete actions (I will perform)
-------------------------------------
1. Tighten the model-client Nix module so it reads envFile securely and documents expected variables.
2. Implement a minimal `apps.coordinator` and `apps.worker` derivation skeleton and smoke tests.
3. Add `tests/scenario/controlplane_e2e.sh` that runs the coordinator and worker in devshell with model-client mocked and verifies transcript creation.
4. Run `./tools/holo-verify.sh` and `./tools/surface-lint.sh` and fix any regressions.

If the above passes, Phase A is complete. Then we can evaluate Phase B additions.
