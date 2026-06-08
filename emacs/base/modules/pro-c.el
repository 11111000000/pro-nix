;;; c.el --- C -*- lexical-binding: t; -*-

(require 'pro-compat)

;; Этот модуль даёт минимальные, но надёжные настройки для C.

(pro-compat--add-to-list-once 'auto-mode-alist '("\\.[ch]\\'" . c-ts-mode))
(pro-compat--add-to-list-once 'auto-mode-alist '("\\.h\\'" . c-ts-mode))

(defun pro-c-setup ()
  "Сделать C-редактирование строгим и предсказуемым."
  (setq-local indent-tabs-mode nil)
  (setq-local c-basic-offset 4))

(defun pro-c-format-buffer ()
  "Показать точку для будущего форматирования C-буфера."
  (interactive)
  (message "[pro-c] formatting hook is intentionally minimal"))

(pro-compat--add-hook-once 'c-ts-mode-hook #'pro-c-setup)

(provide 'pro-c)
