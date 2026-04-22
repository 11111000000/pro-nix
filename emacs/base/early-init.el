;;; early-init.el --- pro Emacs bootstrap -*- lexical-binding: t; -*-

(setq package-enable-at-startup nil)
(setq package-quickstart-file (expand-file-name "quickstart.el" user-emacs-directory))
(setq package-quickstart-sync nil)
(setq frame-inhibit-implied-resize t)
(setq inhibit-splash-screen t)

;; Enable noninteractive auto-install of missing pro packages by default.
;; This environment variable is checked by pro-packages--maybe-install and
;; used to auto-install packages from MELPA when appropriate.
(setenv "PRO_PACKAGES_AUTO_INSTALL" "1")

(provide 'pro-early-init)
