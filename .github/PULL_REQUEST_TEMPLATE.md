# Change Gate

Intent: [one-sentence summary of the change]

Pressure: [Bug | Feature | Debt | Ops]

Surface impact: (none) | touches: <SURFACE item(s)> [FROZEN/FLUID]

Proof: tests: <commands/files that validate this change>

If touching [FROZEN], include Migration block below.

Migration (only when touching [FROZEN]):
- Impact: <SurfaceItem(s) Old→New, scope>
- Strategy: additive_v2 | feature_toggle | break_with_window
- Window/Version: <semver/timeframe>
- Data/Backfill: <steps or "n/a">
- Rollback: <safe revert plan>
- Tests:
  - Keep: <existing tests kept>
  - Add: <new tests>

Checklist (before marking PR ready):
- [ ] I added/updated SURFACE.md if public behavior changed.
- [ ] I added/updated Proof (tests) for any [FROZEN] surface items.
- [ ] I ran `nix flake check` locally and fixed issues.
- [ ] I ran `./tools/holo-verify.sh` and fixed issues.
- [ ] I included a concise Change Gate block above.
