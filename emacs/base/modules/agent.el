;;; agent.el --- агентный буфер -*- lexical-binding: t; -*-

;; Этот модуль держит агентский интерфейс коротким и доступным.

(when (require 'agent-shell nil t)
  (defun pro-agent-open ()
    "Открыть агентский буфер."
    (interactive)
    (agent-shell)))

(provide 'agent)
