# Analysis: System Runtime & Live Activation Failure

Summary
-------
- Symptom A: after switch runtime binaries like `/run/current-system/sw/bin/bash` and `/run/current-system/sw/bin/ssh` disappeared.
- Symptom B: `nixos-rebuild switch` live activation fails with D-Bus / systemd errors: "Rejected send message" when calling org.freedesktop.systemd1.Manager methods (RestartUnit, StartUnit, ListUnitsByPatterns).

Root causes
-----------
1) Package precedence change: module contributions were converted to `lib.mkDefault` while top-level consolidated `environment.systemPackages` is `lib.mkForce`. As a result some packages that used to be added by modules ceased to be present in the final forced list.
2) Live activation race: during `switch` dbus/apparmor reloads and polkit is restarted too early. D-Bus/polkit authorization is transiently unavailable, and systemd method calls are rejected, causing activation to fail.

Key finding about current attempted fix
------------------------------------
- An attempt to mitigate polkit was added to `configuration.nix` under `systemd.services.polkit = lib.mkMerge [...]` and placed `After`/`Wants` inside `serviceConfig`. Those attributes belong either to the module attribute `systemd.services.polkit.after` / `wants` (unit-level) or to the `[Unit]` section. Placing `After`/`Wants` inside `serviceConfig` (which maps to `[Service]`) does not set the unit ordering. Thus the intended mitigation did not apply.

Consequences
------------
- Symptom A is fixable immediately by ensuring essential runtime packages are present in the final `environment.systemPackages` (top-level forced list).
- Symptom B requires correct unit ordering for polkit/dbus and conservative systemd tuning; otherwise live `switch` will continue to be fragile.

Proof & Verification
-------------------
- Build the toplevel and inspect unit files in the result path: confirm polkit's `[Unit]` contains `After=dbus.service`.
- Run `just switch` in a disposable VM and observe journalctl for "Rejected send message". After the fix there should be no such messages during activation.
