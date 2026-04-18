;;; agent.el --- агентный буфер -*- lexical-binding: t; -*-

;; Этот модуль оставляет агентский интерфейс коротким и повторяемым.

(defun pro-agent-open ()
  "Открыть агентский буфер, если пакет доступен."
  (interactive)
  (when (require 'agent-shell nil t)
    (agent-shell)))

(provide 'agent)
