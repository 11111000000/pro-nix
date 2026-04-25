;; Русский: комментарии и пояснения оформлены в стиле учебника
;;; js.el --- JavaScript/TypeScript -*- lexical-binding: t; -*-

(defun pro-js--setup-buffer ()
  "Подготовить JS/TS буфер к работе."
  (setq-local indent-tabs-mode nil)
  (setq-local js-indent-level 2)
  (when (require 'eglot nil t)
    (eglot-ensure)
    (when (fboundp 'eglot-format-buffer)
      (add-hook 'before-save-hook #'eglot-format-buffer nil t))))

(add-to-list 'auto-mode-alist '("\\.js\\'" . js-ts-mode))
(add-to-list 'auto-mode-alist '("\\.mjs\\'" . js-ts-mode))
(add-to-list 'auto-mode-alist '("\\.cjs\\'" . js-ts-mode))
(add-to-list 'auto-mode-alist '("\\.ts\\'" . typescript-ts-mode))
(add-to-list 'auto-mode-alist '("\\.tsx\\'" . tsx-ts-mode))
(add-to-list 'auto-mode-alist '("\\.json\\'" . json-ts-mode))

(add-hook 'js-ts-mode-hook #'pro-js--setup-buffer)
(add-hook 'typescript-ts-mode-hook #'pro-js--setup-buffer)
(add-hook 'tsx-ts-mode-hook #'pro-js--setup-buffer)

(defun pro-js-open-package-json ()
  "Открыть ближайший package.json в проекте."
  (interactive)
  (let ((root (and (fboundp 'pro-project-root) (pro-project-root))))
    (if root
        (find-file (expand-file-name "package.json" root))
      (message "[pro-js] project root not found"))))

(provide 'pro-js)
