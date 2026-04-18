;;; haskell.el --- Haskell -*- lexical-binding: t; -*-

;; Этот модуль включает Haskell только как полезный, но не доминирующий язык.

(add-to-list 'auto-mode-alist '("\\.hs\\'" . haskell-mode))

(defun pro-haskell-setup ()
  "Сделать Haskell-редактирование предсказуемым."
  (setq-local indent-tabs-mode nil)
  (setq-local tab-width 2))

(add-hook 'haskell-mode-hook #'pro-haskell-setup)

(provide 'haskell)
