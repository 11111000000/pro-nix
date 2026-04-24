<!-- Русский: комментарии и пояснения оформлены в стиле учебника -->
# План: локальная оркестрация агентов на NixOS

## Intent

Построить локальную систему, где агенты разработки запускаются воспроизводимо, управляются как сервисы, наблюдаются через явные сигналы состояния и получают секреты только из runtime-источников.

## Pressure

Feature

## Surface impact

touches: Agent Environment [FLUID], Agent Runtime [FLUID], Agent Control Plane [FLUID], Agent Observability [FLUID], Agent Secrets [FROZEN], Agent Deployment [FLUID], Operator UX [FLUID]

## Proof

tests: `./tools/holo-verify.sh`, `./tools/surface-lint.sh`, `nix flake check`, `tests/scenario/example_scenario.test`

## Scope

Этот план не заменяет корневые `SURFACE.md` и `HOLO.md`. Он описывает отдельный слой для agent-orchestration: среда, рантайм, control plane, секреты, деплой и операторский UX.

## Diagnosis

1. `nix develop` и `devshell` решают shell-layer, но не control plane.
2. `devenv` сильнее как единая среда, потому что умеет shell, процессы, тесты, secrets и container outputs.
3. `systemd`/`podman` нужны для долговременных агентов.
4. `deploy-rs` полезен, если появятся несколько хостов.
5. `Podman Desktop` и UI нужны только как operator UX, а не как источник истины.

## Minimal target architecture

1. Environment layer
   - `devenv` or `nix develop`
   - reproducible shell for agent development

2. Runtime layer
   - NixOS `systemd.services.*`
   - `services.podman` or OCI containers

3. Control plane
   - coordinator service
   - worker service
   - queue, retry, timeout, cancel, readiness

4. Secrets layer
   - runtime injection only
   - no API keys in repo or Nix store

5. Deployment layer
   - local: `nixos-rebuild`
   - multi-host: `deploy-rs`

6. Operator UX
   - structured logs
   - health/readiness
   - optional Podman Desktop

## Implementation phases

### Phase 1: contracts

1. Keep root repo-wide `SURFACE.md` and `HOLO.md` as canonical.
2. Keep this plan scoped to agent orchestration.
3. Add a smoke path for secrets and health.

### Phase 2: runtime

1. Add one reference agent runtime service.
2. Add one coordinator service.
3. Add one worker service.

### Phase 3: observability

1. Expose readiness for each service.
2. Emit structured logs.
3. Add a failure-path smoke.

### Phase 4: deployment

1. Keep local activation explicit.
2. Add deploy tooling only if multi-host becomes real.

## Failure modes

1. If secrets are in the repo, stop: this violates the frozen contract.
2. If agents are only shell scripts, the system is not an orchestrator.
3. If there is no readiness signal, debugging will collapse into guesswork.
4. If deployment is undocumented, the platform is not operable.

## Exit criteria

1. One reference agent starts under NixOS control.
2. One runtime secret loads from an operator-managed source.
3. One readiness signal is testable.
4. One vertical scenario proves the path end to end.
