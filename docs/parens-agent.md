Title: Parens Agent for pro-nix emacs

Intent: Provide an automated agent that always detects and, where safe, fixes unbalanced parentheses in Emacs Lisp files under emacs/.
Pressure: Ops
Surface impact: touches: Elisp Parens Checker [FROZEN]
Proof: scripts/check-elisp-parens.el --dir=emacs

Agent design:
- A simple Emacs script (scripts/check-elisp-parens.el) that parses .el files, computes net parentheses balance ignoring strings and comments, and optionally appends missing closing parens at EOF when the balance is positive and <= --max-fix (default 10).
- CI workflow (.github/workflows/elisp-parens.yml) runs the check on push/PR

Behavior and safety:
- Only appends parens when net balance is positive (missing closing parens). Does not attempt to remove extra closing parens (negative balance) because this is unsafe.
- Limits automatic edits to at most --max-fix parens to avoid mass edits or accidental corruption.
- Returns non-zero exit code if any file is unbalanced and not auto-fixed, so CI will fail and require human intervention.
- Script uses syntax-ppss to avoid counting parentheses inside strings and comments.

Avoiding loops:
- The agent is idempotent: appending the exact number of missing closing parens will make the file balanced; subsequent runs see OK.
- CI records and surfaces failures; auto-fix only for small, safe fixes. This prevents repeated noisy fixes and ensures human review when ambiguity exists.

How to run locally:
- Run: emacs --script scripts/check-elisp-parens.el -- --dir=emacs
- To auto-fix small issues: emacs --script scripts/check-elisp-parens.el -- --dir=emacs --fix
- To increase max automatic appended parens: add --max-fix=N

Next steps / improvements:
1. Add unit tests for the script and integrate into existing test harness.
2. Expand static analysis to find mismatched braces in other file types, or use elisp byte-compiler checks for syntax errors.
3. Consider using an AST-based approach (read-from-string) for stricter validation, but that requires careful error handling because read can signal errors on malformed files.
