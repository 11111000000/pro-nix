# Plan: remediate live activation failures and modularize configuration

Intent
- Stabilize live activation (eliminate `Rejected send message` during `switch`) and modularize `configuration.nix` to reduce future regressions.

Pressure
- Ops

Scope and surface impact
- Internal repository changes only: docs, modules, configuration.nix refactor, tests, small guarded change to `scripts/switch.sh`.

Proof (how we'll verify)
- tests/contract/test_system_runtime_paths.spec — ensures bash and ssh exist in build
- tests/contract/test_polkit_unit_order.sh — ensures polkit unit has `After=dbus.service` in produced unit files
- VM smoke: run `nixos-rebuild switch` in disposable VM and assert no `Rejected send message` during activation

Steps
1) Safety prep
  - Create branch `fix/switch-activation` and ensure working tree is saved.

2) Minimal, immediate fixes
  - Ensure `environment.systemPackages` contains minimal runtime packages: `bashInteractive`, `openssh`, `dbus`, `coreutils`, `procps`.
  - Fix polkit ordering: set `systemd.services.polkit.after` and `systemd.services.polkit.wants` (unit-level). Keep `RestartSec` under `serviceConfig`.

3) Refactor configuration into modules (do in small commits)
  - Create `modules/system-boot.nix` (boot, kernel, plymouth)
  - Create `modules/system-nix.nix` (nix settings, substituters)
  - Create `modules/system-locale.nix` (timezone, i18n, sudo defaults)
  - Create `modules/system-services.nix` (libinput, bluetooth, upower, xserver, xdg portals)
  - Create `modules/systemd-policy.nix` (polkit ordering, service-level tweaks, ooms, nix-daemon limits; set `services.dbus.implementation = "broker"` here)
  - Create `modules/packages-runtime.nix` (small list of mandatory runtime packages)
  - Keep `system-packages.nix` as curated large list; modules reference it
  - Update `configuration.nix` to import these modules and compose `environment.systemPackages` from runtime + system-packages.nix

4) Tests
  - Add `tests/contract/test_polkit_unit_order.sh` that builds toplevel and asserts Generated unit contains `After=dbus.service` in [Unit].
  - Ensure `tests/contract/test_system_runtime_paths.spec` exists and passes.

5) Operational guard
  - Update `scripts/switch.sh` (or `just switch` wrapper) to detect `Rejected send message` in `nixos-rebuild switch` output and fall back to `nixos-rebuild boot` with clear operator message.

6) Verification
  - Run `nix build .#nixosConfigurations.huawei.config.system.build.toplevel` and run the two contract tests.
  - Run a VM smoke test for live switch; if not available, use boot+reboot for initial rollout.

Rollout
- Merge to main after tests pass. Initially enable live switch only on non-critical hosts. Monitor for reoccurrence.

Rollback
- Revert module commits or flip a `pro.enableSystemdTuning` flag (kept disabled by default).
