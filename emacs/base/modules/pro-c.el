;; Русский: комментарии и пояснения оформлены в стиле учебника
;;; c.el --- C -*- lexical-binding: t; -*-

;; Этот модуль даёт минимальные, но надёжные настройки для C.

(add-to-list 'auto-mode-alist '("\\.[ch]\\'" . c-ts-mode))
(add-to-list 'auto-mode-alist '("\\.h\\'" . c-ts-mode))

(defun pro-c-setup ()
  "Сделать C-редактирование строгим и предсказуемым."
  (setq-local indent-tabs-mode nil)
  (setq-local c-basic-offset 4))

(defun pro-c-format-buffer ()
  "Показать точку для будущего форматирования C-буфера."
  (interactive)
  (message "[pro-c] formatting hook is intentionally minimal"))

(add-hook 'c-ts-mode-hook #'pro-c-setup)

(provide 'pro-c)
