Name: Elisp Parens Checker
Stability: [FROZEN]
Spec: A repository-level tool that detects unbalanced parentheses in Emacs Lisp files and optionally fixes safe cases by appending closing parens at EOF. It must be runnable locally and in CI.
Proof: scripts/check-elisp-parens.el --dir=emacs
