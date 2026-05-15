Stage: RealityCheck
Purpose: Provide an automated and auditable mechanism to detect and safely fix unbalanced parentheses in Emacs Lisp files under the emacs/ tree.
Invariants:
- INV-Traceability: every run is deterministic and exit code non-zero on failures when not fixed.
- INV-Surface-First: SURFACE.md documents the tool and its proof command.
- INV-Single-Intent: this change only adds paren-check tooling and CI.
Decisions:
- [Frozen] Use simple append-fix strategy for positive net missing-closing-parens. Exit: if false positives appear in 3 CI runs, revisit with stricter checks.
