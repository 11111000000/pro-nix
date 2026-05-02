;;; pro-agent.el --- агентный буфер -*- lexical-binding: t; -*-

;; Этот модуль оставляет агентский интерфейс коротким и повторяемым.

;; Назначение: открыть настроенный agent-shell буфер.
;;
;; Контракт:
;; - Вход: никаких аргументов.
;; - Выход: вызывает agent-shell при успешном обнаружении модуля.
;; - Побочные эффекты: при необходимости выполняет проинициализацию pro-agent-shell-setup.
;; - Ошибки: вызывает user-error если модуль agent-shell недоступен.
(defun pro-agent-open ()
  "Открыть настроенный agent-shell буфер.

Если модуль agent-shell доступен — применяет локальные настройки pro-agent-shell-setup
и открывает интерфейс. Если модуль отсутствует — бросает `user-error`.

Тесты: emacs/base/tests/test-pro-agent.el (при наличии)."
  (interactive)
  (if (require 'agent-shell nil t)
      (progn
        (when (fboundp 'pro-agent-shell-setup)
          (ignore-errors (pro-agent-shell-setup)))
        (agent-shell))
    (user-error "agent-shell integration is not available")))

(provide 'pro-agent)
