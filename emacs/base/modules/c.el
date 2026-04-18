;;; c.el --- C -*- lexical-binding: t; -*-

;; Этот модуль даёт минимальные, но надёжные настройки для C.

(add-to-list 'auto-mode-alist '("\\.[ch]\\'" . c-ts-mode))
(add-to-list 'auto-mode-alist '("\\.h\\'" . c-ts-mode))

(defun pro-c-setup ()
  "Сделать C-редактирование строгим и предсказуемым."
  (setq-local indent-tabs-mode nil)
  (setq-local c-basic-offset 4))

(add-hook 'c-ts-mode-hook #'pro-c-setup)

(provide 'c)
