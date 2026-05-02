;;; ai.el --- compatibility shim -> pro-ai -*- lexical-binding: t; -*-
;; Название: emacs/base/modules/ai.el — Шим-совместимость для pro-ai
;; Цель: предоставить backward-compatible обёртки для существующих вызовов, перенаправляя
;;   на pro-ai. Это облегчает миграцию старого кода к новой реализации pro-ai.
;; Контракт: загружает pro-ai, но не гарантирует наличие всех API; код использует `require` с nil t.
;; Побочные эффекты: загрузка pro-ai может инициализировать глобальные переменные/хуки.
;; Proof: emacs/base/tests/test-ai.el (если присутствует); headless ERT для pro-ai модуля.
;; Last reviewed: 2026-05-02

(require 'pro-ai nil t)
(provide 'ai)

;;; ai.el ends here
