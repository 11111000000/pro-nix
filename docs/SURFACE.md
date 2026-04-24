# Surface: локальная оркестрация агентов

Scope: this document is a scoped sub-spec for the agent-orchestration track. The repo-wide canonical surface remains the root `SURFACE.md`.

## Contract

Репозиторий должен явно описывать и проверять локальную платформу для оркестрации агентов разработки. Контракт делится на четыре слоя:

1. `Environment`
   - Воспроизводимое dev-окружение для сборки, запуска и тестирования агентов.
   - Допустимые входы: `nix develop`, `devenv shell`, `direnv`, `devshell`.

2. `Runtime`
   - Долгоживущие агенты и сервисы запускаются через NixOS/systemd или контейнерный рантайм.
   - Допустимые входы: `systemd.services.*`, `virtualisation.oci-containers`, `services.podman`.

3. `ControlPlane`
   - Оркестрация должна включать очередь задач, retries, timeouts, cancelation и health/readiness checks.
   - Допустимые входы: отдельный coordinator/worker слой, а не один монолитный shell-скрипт.

4. `Operations`
   - Секреты, identity, deployment, observability и operator UX должны быть явными и отделёнными от кода агента.
   - Допустимые входы: `deploy-rs`, `sops-nix`/`age`/operator-managed secrets, structured logs, dashboards, Podman Desktop.

## Surface Items

- Name: Agent Environment
  Stability: [FLUID]
  Spec: The repo provides a reproducible per-project environment for agent development via `nix develop` or an equivalent Nix-native shell.
  Proof: `nix develop` or `devenv shell`

- Name: Agent Runtime
  Stability: [FLUID]
  Spec: Long-running agent services are started by explicit NixOS or container definitions, not by ad hoc manual shell sessions.
  Proof: `nixos-rebuild switch` on a host that exposes the agent services

- Name: Agent Control Plane
  Stability: [FLUID]
  Spec: Agent execution supports queueing, retries, cancellation, readiness, and per-agent lifecycle control.
  Proof: a dedicated coordinator/worker smoke scenario

- Name: Agent Observability
  Stability: [FLUID]
  Spec: Agent runtime exposes structured logs and a health/readiness endpoint or equivalent local signal.
  Proof: `tests/contract/test_agent_observability.sh`

- Name: Agent Secrets
  Stability: [FROZEN]
  Spec: API keys and credentials must never be committed to the repository; they are injected at runtime from an operator-managed secret source.
  Proof: `rg "api[-_ ]?key|secret|token" -n docs/ AGENTS.md README.md` and `tests/contract/test_agent_secrets.sh`

- Name: Agent Deployment
  Stability: [FLUID]
  Spec: Multi-host deployment uses flake-based deploy tooling and keeps rollback behavior explicit.
  Proof: `deploy-rs` or `nixos-rebuild --flake` verification

- Name: Operator UX
  Stability: [FLUID]
  Spec: The repo documents a human operator path for starting, inspecting, and stopping agent services.
  Proof: docs + a manual smoke path

## Notes

- `devenv` is the strongest candidate for the environment layer when the project needs shell, processes, tests, secrets, and container outputs in one place.
- `devshell` remains a lighter option when the project only needs a reproducible shell.
- `direnv` is a glue layer, not a control plane.
- `Podman Desktop` is operator UX, not source of truth.
