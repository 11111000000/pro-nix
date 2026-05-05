;; Русский: комментарии и пояснения оформлены в учебном стиле (пояснения и примеры)
;;; java.el --- Java -*- lexical-binding: t; -*-

;; Этот модуль оставляет Java без лишнего шума, но с полезной поддержкой.

(add-to-list 'auto-mode-alist '("\\.java\\'" . java-ts-mode))

(defun pro-java-setup ()
  "Сделать Java-редактирование спокойным и аккуратным."
  (setq-local indent-tabs-mode nil)
  (setq-local tab-width 4))

(defun pro-java-open-project ()
  "Переход к проектной работе в Java-буфере."
  (interactive)
  (message "[pro-java] project entrypoint is intentionally minimal"))

(when (or (pro--package-provided-p 'eglot) (pro-packages--maybe-install 'eglot t) (require 'eglot nil t))
  (add-hook 'java-ts-mode-hook #'eglot-ensure))

(add-hook 'java-ts-mode-hook #'pro-java-setup)

(provide 'pro-java)
