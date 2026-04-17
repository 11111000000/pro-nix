;;; core.el --- base editing defaults -*- lexical-binding: t; -*-

(setq inhibit-startup-screen t
      inhibit-startup-message t
      initial-scratch-message ""
      ring-bell-function #'ignore
      use-dialog-box nil
      create-lockfiles nil
      make-backup-files nil)

(setq backup-directory-alist
      `(("." . ,(expand-file-name "backups/" user-emacs-directory))))
(setq auto-save-file-name-transforms
      `((".*" ,(expand-file-name "auto-save/" user-emacs-directory) t)))

(provide 'core)
