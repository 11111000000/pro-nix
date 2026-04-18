;;; core.el --- ядро Emacs -*- lexical-binding: t; -*-

;; Этот модуль держит самые общие и тихие правила среды.

(setq-default indent-tabs-mode nil)
(setq-default fill-column 88)
(setq ring-bell-function 'ignore)

(when (fboundp 'global-auto-revert-mode)
  (global-auto-revert-mode 1))

(provide 'core)
