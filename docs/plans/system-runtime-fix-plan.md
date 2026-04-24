# Plan: Fix live activation race and refactor configuration

Intent
- Stabilize `nixos-rebuild switch` live activation (eliminate
  `Rejected send message` errors) and refactor `configuration.nix` into
  small modules to reduce blast radius for future changes.

Pressure: Ops

Scope
- Affects internal repo configuration only. No public API changes.

Deliverables
1. Immediate: correct polkit unit ordering and pin dbus broker; add
   runtime packages to top-level (already present).
2. Tests: add contract tests for runtime paths and polkit unit order.
3. Refactor: split configuration.nix into modules and update imports.
4. Operational: update `scripts/switch.sh` to fallback to `nixos-rebuild boot`
   when `Rejected send message` is detected.

Steps
1) Create module `modules/systemd-policy.nix` with:
   - services.dbus.implementation = "broker";
   - systemd.services.polkit.after = [ "dbus.service" "sysinit-reactivation.target" ];
   - systemd.services.polkit.wants = [ "dbus.service" ];
   - systemd.services.polkit.serviceConfig.RestartSec = "3s";

2) Create `modules/packages-runtime.nix` exporting a list of mandatory
   runtime packages: bashInteractive, openssh, coreutils, procps, dbus.

3) Move concerns out of `configuration.nix` into modules:
   - boot: boot.loader*, kernelPackages
   - locale: i18n, timezone, sudo
   - nix: nix.settings, nixpkgs.config
   - services: bluetooth, libinput, upower, xdg portal, fonts
   - systemd-policy: polkit/dbus tuning

4) Update `configuration.nix` to import the new modules and compose
   environment.systemPackages via `lib.mkForce` from `packages-runtime` and
   `system-packages.nix`.

5) Add tests in `tests/contract`:
   - test_system_runtime_paths.spec (executable checks)
   - test_polkit_unit_order.sh (grep built unit)

6) Update `scripts/switch.sh` to detect `Rejected send message` and
   fallback to `nixos-rebuild boot` with a clear message to reboot.

Verification
- Run `nix build .#nixosConfigurations.huawei.config.system.build.toplevel`.
- Run contract tests.
- Run VM-based live switch smoke test.

Rollback
- Revert the modules/systemd-policy.nix and packages change; fall back to
  boot+reboot path.

Timeline
- Implement immediate fixes and tests (~30-60m).
- Refactor modules (~1-2h) with testing.
