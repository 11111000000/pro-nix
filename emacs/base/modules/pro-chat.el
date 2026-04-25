;; Русский: комментарии и пояснения оформлены в стиле учебника
;;; chat.el --- Telegram и чаты -*- lexical-binding: t; -*-

;; Этот модуль подключает чаты как полезный, но не навязчивый канал коммуникации.

(defun pro-chat-open ()
  "Открыть Telegram, если пакет доступен."
  (interactive)
  (when (require 'telega nil t)
    (telega)))

(provide 'pro-chat)
