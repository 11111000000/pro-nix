;;; agent.el --- агентный буфер -*- lexical-binding: t; -*-

;; Этот модуль оставляет агентский интерфейс коротким и повторяемым.

(defun pro-agent-open ()
  "Open configured agent-shell buffer.

This ensures the local pro-agent-shell setup is applied before
starting the package's UI. If the agent-shell module isn't
available, signal a user error so the caller knows why nothing
happened." 
  (interactive)
  (unless (require 'agent-shell nil t)
    (user-error "agent-shell integration is not available"))
  ;; Ensure our pro config is applied (the module's top-level code
  ;; runs pro-agent-shell-setup when loaded). Call the setup again
  ;; to be idempotent and make sure runtime options are applied.
  (when (fboundp 'pro-agent-shell-setup)
    (ignore-errors (pro-agent-shell-setup)))
  (agent-shell))

(provide 'agent)
