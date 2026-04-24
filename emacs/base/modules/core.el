;; Русский: комментарии и пояснения оформлены в стиле учебника
;;; pro-core.el --- ядро Emacs -*- lexical-binding: t; -*-

;; Этот модуль держит самые общие и тихие правила среды.

(setq-default indent-tabs-mode nil)
(setq-default fill-column 88)
(setq ring-bell-function 'ignore)
(setq make-backup-files t
      backup-by-copying t
      version-control t
      kept-new-versions 6
      kept-old-versions 2
      delete-old-versions t)
(setq backup-directory-alist `(("." . ,(expand-file-name "backups/" user-emacs-directory))))
;; Ensure the auto-save directory exists; otherwise Emacs reports errors when
;; trying to write auto-save files for paths (e.g. files in /nix/store).
(setq auto-save-file-name-transforms `((".*" ,(expand-file-name "auto-save/" user-emacs-directory) t)))
(let ((pro-auto-dir (expand-file-name "auto-save/" user-emacs-directory)))
  (unless (file-directory-p pro-auto-dir)
    (make-directory pro-auto-dir t)))

(when (fboundp 'global-auto-revert-mode)
  (global-auto-revert-mode 1))
(when (fboundp 'save-place-mode)
  (save-place-mode 1))
(when (fboundp 'savehist-mode)
  (savehist-mode 1))
(when (fboundp 'recentf-mode)
  (recentf-mode 1)
  (setq recentf-max-saved-items 200
        recentf-auto-cleanup 'never))
(when (fboundp 'electric-pair-mode)
  (electric-pair-mode 1))
(when (fboundp 'show-paren-mode)
  (show-paren-mode 1))

(setq sentence-end-double-space nil)
(setq use-short-answers t)
(setq confirm-kill-emacs 'y-or-n-p)
(setq initial-scratch-message "")
(setq visible-bell nil)
(setq create-lockfiles nil)
(setq vc-follow-symlinks t)
(setq require-final-newline t)

(provide 'pro-core)
(provide 'core)

;;; pro-core.el ends here
