;; Русский: комментарии и пояснения оформлены в стиле учебника
;;; lisp.el --- Lisp и структурное редактирование -*- lexical-binding: t; -*-

;; Этот модуль усиливает главную конфигурационную среду: Emacs Lisp.

(show-paren-mode 1)
(setq show-paren-delay 0)

(defun pro-lisp-setup ()
  "Подготовить Lisp-редактирование как основную среду разработки конфига."
  (setq-local indent-tabs-mode nil)
  (setq-local fill-column 88))

(defun pro-lisp-eval-buffer ()
  "Оценить буфер как рабочий Lisp-артефакт."
  (interactive)
  (when (derived-mode-p 'emacs-lisp-mode 'lisp-interaction-mode)
    (eval-buffer)))

(when (or (pro--package-provided-p 'rainbow-delimiters) (pro-packages--maybe-install 'rainbow-delimiters t) (require 'rainbow-delimiters nil t))
  ;; Guard mode function in case package is partially loaded.
  (when (fboundp 'rainbow-delimiters-mode)
    (add-hook 'emacs-lisp-mode-hook #'rainbow-delimiters-mode)
    (add-hook 'lisp-interaction-mode-hook #'rainbow-delimiters-mode)))

(add-hook 'emacs-lisp-mode-hook #'pro-lisp-setup)
(add-hook 'lisp-interaction-mode-hook #'pro-lisp-setup)

(provide 'lisp)
