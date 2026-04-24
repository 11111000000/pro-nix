# Plan: restore core runtime paths

## Change Gate

- Intent: restore `bash` and `ssh` to the default system runtime PATH so the switched system remains usable.
- Pressure: Bug
- Surface impact: touches `SystemRuntimePaths` [FLUID]
- Proof: tests/contract/test_system_runtime_paths.spec; `nix build .#nixosConfigurations.huawei.config.system.build.toplevel --no-link`

## Thesis

The new package-precedence shape is good: the final system profile is now centrally assembled and easier to reason about.

## Antithesis

The same shape can silently delete core runtime tools if the forced list omits them. That is exactly what happened here: the system still built, but the switch left the machine without `bash` and `ssh` in the expected `sw/bin` paths.

## Synthesis

Keep the centralized package assembly, but make the core runtime baseline explicit. The Tao here is not to abolish structure; it is to leave the necessary things in place and not overfit the list to modules that no longer participate.

## Final plan

1. Document the regression and the path contract in `docs/analyse/` and `SURFACE.md`.
2. Add a contract test that builds the default system profile and checks `sw/bin/bash` and `sw/bin/ssh`.
3. Patch `configuration.nix` to include `bashInteractive` and `openssh` in the forced system package list.
4. Drop the structured `systemd.settings` block that makes switch-time reactivation less predictable.
5. Verify the host build and the contract test together.

## Critique of the plan

The tempting alternative is to loosen the force and let module defaults flow again. That would be less explicit, but it would also reintroduce the class of precedence bugs the refactor was trying to solve.

So the narrow fix is better: keep one decisive top-level list, teach it the minimum runtime tools it must never omit, and remove the manager-level tuning that is unrelated to the user-visible runtime contract.
