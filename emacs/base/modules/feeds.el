;;; feeds.el --- ленты новостей -*- lexical-binding: t; -*-

;; Этот модуль включает чтение лент как часть рабочего потока.

(when (require 'elfeed nil t)
  (defun pro-feeds-open ()
    "Открыть ленты."
    (interactive)
    (elfeed)))

(provide 'feeds)
