# System runtime activation failure — analysis

Summary
- Symptoms: `nixos-rebuild switch` fails during activation with repeated
  `Rejected send message` errors for systemd D-Bus calls (RestartUnit,
  StartUnit, ListUnitsByPatterns). Separately, `/run/current-system/sw/bin/bash`
  and `/run/current-system/sw/bin/ssh` were missing after a previous switch.

Findings
- Two related but distinct issues were present:
  1. Missing runtime binaries (bash/ssh) — caused by a change in package
     precedence: modules began to contribute packages with `lib.mkDefault`,
     while a top-level `environment.systemPackages` was enforced with
     `lib.mkForce`. The top-level list omitted some packages previously
     provided by modules, so they stopped appearing in the final profile.
  2. Live activation race — during `switch` activation the sequence
     `reload dbus/apparmor` followed immediately by `restart polkit` led to
     transient unavailability of D‑Bus authorisation. Systemd then rejected
     method calls (org.freedesktop.systemd1.Manager) and activation cascaded
     into failures.

Key misconfiguration
- A previous attempt to mitigate the polkit/dbus race put `After` and
  `Wants` under `serviceConfig` (the [Service] section), so the ordering
  directives did not apply. The ordering attributes must live at the unit
  level (`systemd.services.<name>.after`, `.wants`, `.requires`). As a
  consequence, polkit still could restart too early.

Immediate corrective actions taken
- Ensured top-level `environment.systemPackages` explicitly includes
  `bashInteractive` and `openssh` (forced). This restores the basic runtime
  tools immediately.

Recommended (optimal) solution
1. Short-term safety
   - Use `nixos-rebuild boot` + reboot for production hosts until the live
     activation path is proven stable.
   - Keep explicit minimal runtime package list in top-level configuration.

2. Proper fix for activation race
   - Put polkit unit ordering in the correct unit attributes:
     - `systemd.services.polkit.after = [ "dbus.service" ]`
     - `systemd.services.polkit.wants = [ "dbus.service" ]`
     - Optionally `requires` if hard dependency desired.
   - Keep `RestartSec` in `serviceConfig` to add a small delay.
   - Prefer `services.dbus.implementation = "broker"` to reduce broker
     instability window.

3. Structural change (refactor configuration into modules)
   - Split configuration into small single-responsibility modules: boot,
     locale, nix, services, systemd-policy, runtime-packages.
   - Keep `configuration.nix` as a thin compositor importing these modules.

Verification / Proof
- Contract tests to add/run:
  - sw runtime test: assert `/run/current-system/sw/bin/{bash,ssh}` exist
  - polkit unit order test: built toplevel contains `After=dbus.service`
  - smoke test: VM-based `switch` shows no `Rejected send message`

Risks
- Manager-level systemd tuning (global PID1 settings) can amplify
  activation fragility; such tuning must be gated and tested in VM.

Conclusion
- The correct fix is small: move ordering directives to the correct unit
  attributes and ensure mandatory runtime packages are always present.
  The module split reduces future risk and makes the system more harmonious
  and testable.
