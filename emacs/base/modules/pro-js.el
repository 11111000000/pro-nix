;;; js.el --- JavaScript/TypeScript -*- lexical-binding: t; -*-

(require 'pro-compat)

(defun pro-js--setup-buffer ()
  "Подготовить JS/TS буфер к работе."
  (setq-local indent-tabs-mode nil)
  (setq-local js-indent-level 2)
  (when (require 'eglot nil t)
    (eglot-ensure)
    (when (fboundp 'eglot-format-buffer)
      (add-hook 'before-save-hook #'eglot-format-buffer nil t))))

(pro-compat--add-to-list-once 'auto-mode-alist '("\\.js\\'" . js-ts-mode))
(pro-compat--add-to-list-once 'auto-mode-alist '("\\.mjs\\'" . js-ts-mode))
(pro-compat--add-to-list-once 'auto-mode-alist '("\\.cjs\\'" . js-ts-mode))
(pro-compat--add-to-list-once 'auto-mode-alist '("\\.ts\\'" . typescript-ts-mode))
(pro-compat--add-to-list-once 'auto-mode-alist '("\\.tsx\\'" . tsx-ts-mode))
(pro-compat--add-to-list-once 'auto-mode-alist '("\\.json\\'" . json-ts-mode))

(pro-compat--add-hook-once 'js-ts-mode-hook #'pro-js--setup-buffer)
(pro-compat--add-hook-once 'typescript-ts-mode-hook #'pro-js--setup-buffer)
(pro-compat--add-hook-once 'tsx-ts-mode-hook #'pro-js--setup-buffer)

(defun pro-js-open-package-json ()
  "Открыть ближайший package.json в проекте."
  (interactive)
  (let ((root (and (fboundp 'pro-project-root) (pro-project-root))))
    (if root
        (find-file (expand-file-name "package.json" root))
      (message "[pro-js] project root not found"))))

(provide 'pro-js)
