;;; chat.el --- compatibility shim -> pro-chat -*- lexical-binding: t; -*-
;; Название: emacs/base/modules/chat.el — Шим для совместимости с pro-chat
;; Цель: предоставить backward-compatible обёртки и alias'ы для существующих вызовов,
;;   которые ожидали feature `chat`.
;; Контракт: загружает pro-chat, не вызывает ошибку при отсутствии (require с nil t).
;; Побочные эффекты: может регистрировать ключи и открывать буферы; поведение зависит от pro-chat.
;; Proof: headless ERT для pro-chat или emacs/base/tests/test-chat.el если имеется.
;; Last reviewed: 2026-05-02

(require 'pro-chat nil t)
(provide 'chat)

;;; chat.el ends here
