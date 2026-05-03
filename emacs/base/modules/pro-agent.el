;;; pro-agent.el --- агентный буфер -*- lexical-binding: t; -*-

;; Назначение: открыть настроенный agent-shell буфер.
;;
;; Контракт:
;; - Вход: никаких аргументов.
;; - Выход: вызывает agent-shell при успешном обнаружении модуля.
;; - Побочные эффекты: при необходимости выполняет инициализацию pro-agent-shell-setup.
;; - Ошибки: вызывает user-error если модуль agent-shell недоступен.
;;
;; Публичные функции:
;; - pro-agent-open: открывает agent-shell с применением локальной конфигурации.
;;
;; Тесты: emacs/base/tests/test-pro-agent.el (headless ERT)
;; Last reviewed: 2026-05-02

(defun pro-agent-open ()
  "Открыть настроенный agent-shell буфер.

Если модуль `agent-shell' доступен — применяется локальная инициализация
`pro-agent-shell-setup' (игнорируем ошибки в setup) и вызывается `agent-shell'.
Если модуль отсутствует — бросается `user-error'.

Побочные эффекты: может установить переменные окружения и записать транскрипты в пользовательский каталог.
Тесты: emacs/base/tests/test-pro-agent.el (headless ERT)."
  (interactive)
  (if (require 'agent-shell nil t)
      (progn
        (when (fboundp 'pro-agent-shell-setup)
          (ignore-errors (pro-agent-shell-setup)))
        (agent-shell))
    (user-error "agent-shell integration is not available")))

(provide 'pro-agent)
