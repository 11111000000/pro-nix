;;; js.el --- JavaScript/TypeScript -*- lexical-binding: t; -*-

(add-to-list 'auto-mode-alist '("\\.js\\'" . js-ts-mode))
(add-to-list 'auto-mode-alist '("\\.mjs\\'" . js-ts-mode))
(add-to-list 'auto-mode-alist '("\\.cjs\\'" . js-ts-mode))
(add-to-list 'auto-mode-alist '("\\.ts\\'" . typescript-ts-mode))
(add-to-list 'auto-mode-alist '("\\.tsx\\'" . tsx-ts-mode))
(add-to-list 'auto-mode-alist '("\\.json\\'" . json-ts-mode))

(when (require 'eglot nil t)
  (add-hook 'js-ts-mode-hook #'eglot-ensure)
  (add-hook 'typescript-ts-mode-hook #'eglot-ensure)
  (add-hook 'tsx-ts-mode-hook #'eglot-ensure))

(provide 'js)
