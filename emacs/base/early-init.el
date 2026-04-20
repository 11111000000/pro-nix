;;; early-init.el --- pro Emacs bootstrap -*- lexical-binding: t; -*-

(setq package-enable-at-startup nil)
(setq package-quickstart-file (expand-file-name "quickstart.el" user-emacs-directory))
(setq package-quickstart-sync nil)
(setq frame-inhibit-implied-resize t)
(setq inhibit-splash-screen t)

(provide 'pro-early-init)
