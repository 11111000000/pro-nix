# Change Gate: CI fixes verification

Intent: Verify CI fixes merged to main and attach verification logs
Pressure: Ops
Surface impact: none (internal fixes: flake test wiring and avahi service XML; no changes to SURFACE.md entries)

Proof commands run:
- ./tools/holo-verify.sh --details

- ./tools/surface-lint.sh
Merged PRs: #7 #8 #9 #10 #11 #12 #13

=== holo-verify.log (full output) ===

Running holo verification from /home/az/pro-nix
== Skipping non-shell contract file: ert-session.el
== Skipping non-shell contract file: ert-soft-reload.el
== Running contract script: pro-peer-01.sh
pro-peer: authorized_keys mentioned in module
== Running contract script: surface-headers.sh
All module headers present
== Running contract test: test-gui-smoke.el
root HOLO does not reference the GUI smoke proof
=== surface-lint.log ===

SURFACE.md found
Proof present: tests/contract/test-soft-reload.el
Proof present: tests/contract/test_surface_health.spec
Proof present: tests/contract/test-theme-contrast.el
Proof present: tests/contract/unit/03-llm-tools.sh
surface-lint: OK
