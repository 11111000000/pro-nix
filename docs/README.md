Analysis artifacts
==================

This directory contains a machine-friendly analysis of the pro-nix repository
produced by an automated agent on 2026-04-25. Files:

- analyse/00-overview.md — goals and method
- analyse/01-modules.md — modules catalog
- analyse/02-tests.md — tests and proofs
- analyse/03-analysis.md — dialectical analysis
- analyse/04-recommendations.md — prioritized improvements and steps
- analyse/05-enumerated-functions.md — scripts and entrypoints list

Use `tools/holo-verify.sh` to run contract tests referenced in HOLO.md. Use
`tools/surface-lint.sh` to ensure SURFACE.md and referenced proofs are present.
