;;; lisp.el --- Lisp и структурное редактирование -*- lexical-binding: t; -*-

;; Этот модуль усиливает главную конфигурационную среду: Emacs Lisp.

(show-paren-mode 1)
(setq show-paren-delay 0)

(defun pro-lisp-setup ()
  "Подготовить Lisp-редактирование как основную среду разработки конфига."
  (setq-local indent-tabs-mode nil)
  (setq-local fill-column 88))

(when (require 'rainbow-delimiters nil t)
  (add-hook 'emacs-lisp-mode-hook #'rainbow-delimiters-mode)
  (add-hook 'lisp-interaction-mode-hook #'rainbow-delimiters-mode))

(add-hook 'emacs-lisp-mode-hook #'pro-lisp-setup)
(add-hook 'lisp-interaction-mode-hook #'pro-lisp-setup)

(provide 'lisp)
