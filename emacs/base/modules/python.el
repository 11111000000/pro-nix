;;; python.el --- Python -*- lexical-binding: t; -*-

;; Этот модуль настраивает Python как рабочий язык для скриптов и блоков org-babel.

(add-to-list 'auto-mode-alist '("\\.py\\'" . python-ts-mode))

(defun pro-python-setup ()
  "Сделать Python более предсказуемым для редактирования и запуска."
  (setq-local indent-tabs-mode nil)
  (setq-local python-indent-offset 4))

(defun pro-python-run-buffer ()
  "Запустить текущий Python-буфер как сценарий."
  (interactive)
  (when buffer-file-name
    (compile (format "python %s" (shell-quote-argument buffer-file-name)))))

(when (require 'eglot nil t)
  (add-hook 'python-ts-mode-hook #'eglot-ensure))

(add-hook 'python-ts-mode-hook #'pro-python-setup)

(provide 'python)
