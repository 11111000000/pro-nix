;;; core.el --- compatibility shim -> pro-core -*- lexical-binding: t; -*-
;; Compatibility shim for legacy name `core.el`. Loads `pro-core` and
;; provides the legacy feature `core` for tests and external code that still
;; reference the old name.

(require 'pro-core nil t)
(provide 'core)

;;; core.el ends here
