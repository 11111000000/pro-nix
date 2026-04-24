Stage: RealityCheck

Scope: this document is a scoped manifest for the agent-orchestration track. The repo-wide canonical manifest remains the root `HOLO.md`.

Purpose: Define the minimum holographic contract for a local agent orchestration platform on NixOS. The goal is to keep environment, runtime, control plane, deployment, secrets, and operator UX explicitly separated so the system stays reproducible and debuggable.

Invariants:
- INV-Core-IO-Boundary: agent policy and orchestration logic stay separate from shell wrappers and host-specific IO.
- INV-Determinism: the same flake inputs produce the same environment and runtime definitions.
- INV-Canonical-Roundtrip: frozen contracts about secrets and health signals remain checkable and do not silently weaken.
- INV-Compat-Policy: public surfaces evolve additively unless a migration is documented.
- INV-Traceability: every public change carries Intent, Pressure, Surface impact, and Proof.
- INV-Surface-First: external meaning changes start in docs/SURFACE.md.
- INV-Single-Intent: one change, one dominant goal.

Decisions:
- [Draft] Use `devenv` as the default candidate for local agent environments when the project needs shells plus processes, tests, and secrets in one layer. Exit: the environment layer is reproducible and documented, and the chosen tool does not leak secrets into the repo.
- [Draft] Use NixOS `systemd` or `virtualisation.oci-containers` for long-running agent runtimes. Exit: a reference agent can start, expose readiness, and stop cleanly on a host.
- [Draft] Introduce a separate control-plane component for queueing, retries, cancellation, and readiness. Exit: the control plane is independently testable from agent logic.
- [FROZEN] Agent Secrets: credentials must be injected at runtime from an operator-managed secret source and never committed. Exit: secret-loading path exists and `tests/contract/test_agent_secrets.sh` passes.
- [Draft] Agent Observability: expose structured logs and a readiness signal for each agent service. Exit: `tests/contract/test_agent_observability.sh` passes and the signal is documented.
- [Draft] GUI smoke proof: keep a GUI smoke contract file referenced by the root manifest. Exit: `tests/contract/test-gui-smoke.el` exists and root `HOLO.md` references it.
