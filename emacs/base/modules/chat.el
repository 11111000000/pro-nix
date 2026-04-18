;;; chat.el --- Telegram и чаты -*- lexical-binding: t; -*-

;; Этот модуль подключает чаты только как полезную рабочую поверхность.

(when (require 'telega nil t)
  (defun pro-chat-open ()
    "Открыть Telegram."
    (interactive)
    (telega)))

(provide 'chat)
