;; Русский: комментарии и пояснения оформлены в стиле учебника
;;; haskell.el --- Haskell -*- lexical-binding: t; -*-

;; Этот модуль включает Haskell только как полезный, но не доминирующий язык.

(add-to-list 'auto-mode-alist '("\\.hs\\'" . haskell-mode))

(defun pro-haskell-setup ()
  "Сделать Haskell-редактирование предсказуемым."
  (setq-local indent-tabs-mode nil)
  (setq-local tab-width 2))

(defun pro-haskell-open-repl ()
  "Показать точку для REPL-потока Haskell."
  (interactive)
  (message "[pro-haskell] repl entrypoint is intentionally minimal"))

(add-hook 'haskell-mode-hook #'pro-haskell-setup)

(provide 'haskell)
