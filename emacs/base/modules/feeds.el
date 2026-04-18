;;; feeds.el --- ленты новостей -*- lexical-binding: t; -*-

;; Этот модуль удерживает ленты как отдельную рабочую поверхность, без лишнего шума.

(defun pro-feeds-open ()
  "Открыть ленты, если пакет доступен."
  (interactive)
  (when (require 'elfeed nil t)
    (elfeed)))

(provide 'feeds)
