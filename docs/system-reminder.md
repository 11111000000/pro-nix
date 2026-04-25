# System Reminder — Agent Factory Implementation Plan

This document records the detailed analysis and step-by-step plan to implement a local "agent factory" on NixOS for software development use-cases. It assumes: no local hosting of large models, sqlitevec/chroma-lite as the local retrieval engine, Redis as task broker, sops-nix/age for secrets, systemd-first runtime with optional podman containerization, single-host deployment.

Status
------
- Mode: build (implement changes).
- Goal: provide reproducible Nix-native orchestration for agents that interact with external model providers and local retrieval/eval infrastructure — without downloading large models locally.

High-level architecture
-----------------------
Layers:
- Environment: flakes + devShells + llm-lab for research.
- Runtime: systemd units (NixOS modules) + optional podman images.
- Control plane: coordinator (HTTP) + worker runtime (queue via Redis).
- Retrieval: sqlitevec / chroma-lite wrapper (local RAG store).
- Model client: proxy that standardizes calls to external model providers (reads API keys from runtime env).
- Evaluation: eval harness CLI and notebook integration.
- Operations: secrets (sops-nix/age), resource slices, observability, smoke tests.

Design decisions (confirmed)
---------------------------
- Retrieval engine: sqlitevec / chroma-lite (lightweight local index).
- Queue backend: Redis.
- Secrets: sops-nix / age preferred (repo-centric encrypted secrets) + environment files managed by operator.
- Runtime: systemd units as primary; podman optional for containerized workers.
- Deployment: single-host (no Kubernetes) and no automatic model download.

Concrete files to add (first iteration)
------------------------------------
Documentation & contracts:
- docs/SURFACE.md (update — new surface items for Model Client, Control Plane, Worker, Retrieval, Evaluation) — already added placeholders; ensure references.
- docs/HOLO.md (update decisions + Proof references) — updated.
- docs/operators/agents-setup.md (runbook for enabling modules and injecting secrets)

NixOS modules (nixos/modules):
- nixos/modules/agents-model-client.nix — systemd unit + options: enable, listenAddress, envFile, slice settings
- nixos/modules/agents-retrieval.nix — optional sqlitevec service + storagePath
- nixos/modules/agents-control.nix — coordinator + worker systemd templates and options

Derivations and apps (flake outputs):
- flake outputs: apps.x86_64-linux.model-client (FastAPI proxy derivation)
- apps.x86_64-linux.retrieval-server (sqlitevec wrapper)
- apps.x86_64-linux.coordinator (minimal Python HTTP server)
- apps.x86_64-linux.worker (minimal worker)

Scripts / smoke tests (tests/contract, tests/scenario):
- tests/contract/test_modelclient_smoke.sh
- tests/contract/test_retrieval_smoke.sh
- tests/scenario/controlplane_e2e.sh (mocked model client)
- tests/contract/test_agent_secrets.sh (exists) — ensure references

Dev UX and helper scripts:
- scripts/dev/run-model-client.sh (run derivation in devshell)
- scripts/dev/run-retrieval.sh

Observability & resources
-------------------------
- systemd slices: agents.slice with defaults (MemoryMax=4G, CPUQuota=80%, IOWeight=200)
- each service: /health, /ready endpoints and /metrics (Prom text format)
- logs: JSON to stdout (journald collects)

Secrets model
-------------
- Primary: sops-nix (encrypted YAML committed) + nixos module support to decrypt at build/activation OR
- Operator flow: place /etc/agents/model-client.env with mode 600 and set module option points to it.
- Tests ensure no plain secrets are committed (tests/contract/test_agent_secrets.sh)

Step-by-step implementation plan (phases)
----------------------------------------
Phase 0 — contracts (small, safe)
1. Add/update SURFACE.md & HOLO.md entries for new surfaces (Model Client, Control Plane, Worker, Retrieval, Evaluation) and reference proof scripts.
2. Add stub smoke tests in tests/contract (scripts that initially assert configuration/docs presence).
Proof: run ./tools/holo-verify.sh and ./tools/surface-lint.sh.

Phase 1 — Model Client (first runnable service)
1. Create derivation apps.model-client (FastAPI proxy) that reads MODEL_API_URL and MODEL_API_KEY from env and proxies requests; no model download.
2. Add nixos/modules/agents-model-client.nix to create systemd service and configure slice.
3. Add tests/contract/test_modelclient_smoke.sh that can run the derivation in devshell and call /health.
Proof: holo-verify passes smoke test.

Phase 2 — Retrieval (sqlitevec/chroma-lite)
1. Add derivation apps.retrieval-server (Python wrapper around sqlitevec or chroma-lite bindings).
2. Add nixos/modules/agents-retrieval.nix for service management (disabled by default).
3. Add tests/contract/test_retrieval_smoke.sh performing upsert + query in devshell.

Phase 3 — Control plane (coordinator + worker) & Broker
1. Add derivations apps.coordinator and apps.worker (minimal Python reference implementations using Redis).
2. Add nixos/modules/agents-control.nix with systemd units (coordinator.service, worker@.service template), config options and Redis connection.
3. Add tests/scenario/controlplane_e2e.sh that runs coordinator + worker against a mocked model client and checks transcript output.

Phase 4 — Secrets, Observability, Eval harness
1. Add sops-nix integration doc and example sealed secret for model client (operator to decrypt and place env file) — docs/operators/agents-setup.md.
2. Add metrics endpoints and promote standard JSON logging in services.
3. Add apps.eval-run derivation and example notebooks in llm-lab.

Phase 5 — Podman option & optional components
1. Provide podman image derivations for worker/coordinator for operator to run in container.
2. Optionally add qdrant module for more advanced retrieval.

Tests and CI
------------
- Add new test scripts to tests/contract and tests/scenario and wire them into ./tools/holo-verify.sh.
- CI should run `nix flake check` and holo-verify in unit mode.

Commands to run locally (developer)
---------------------------------
- devshell: `nix develop .#devShells.x86_64-linux.default`
- run model client in devshell: `nix run .#model-client` or `python -m model_client.app --config dev.env`
- run retrieval smoke in devshell: `nix run .#retrieval-server` and `rag-cli upsert/query`
- run controlplane e2e (dev): `bash tests/scenario/controlplane_e2e.sh`

Files to expect in repository after implementation (summary)
----------------------------------------------------------------
- nixos/modules/agents-model-client.nix
- nixos/modules/agents-retrieval.nix
- nixos/modules/agents-control.nix
- flake.nix updates: outputs.apps.{model-client,retrieval-server,coordinator,worker,eval-run}
- scripts/dev/* and scripts/smoke/*
- tests/contract/test_modelclient_smoke.sh
- tests/contract/test_retrieval_smoke.sh
- tests/scenario/controlplane_e2e.sh
- docs/operators/agents-setup.md

Next immediate action (I will perform now)
-----------------------------------------
1. Create the contract stubs and surface/HOLO updates if not already present (safe docs + tests).
2. Add model-client module skeleton and a minimal Python proxy derivation (flake output) — implement smoke test that runs the derivation in devshell and hits /health.

If you confirm, I will start implementing Phase 0 -> Phase 1 now and create commits per step. If you want a different ordering, reply with changes.
