;;; init.el --- pro Emacs loader -*- lexical-binding: t; -*-

(let ((base-dir (file-name-directory (or load-file-name buffer-file-name))))
  (setq user-emacs-directory (file-name-as-directory (expand-file-name "~/.config/emacs/")))
  (setq pro-emacs-base-system-modules-dir (expand-file-name "modules" base-dir))
  ;; Load pro-compat and pro-packages early so modules can consult them
  (when (file-readable-p (expand-file-name "pro-compat.el" pro-emacs-base-system-modules-dir))
    (load (expand-file-name "pro-compat.el" pro-emacs-base-system-modules-dir) nil t))
  (when (file-readable-p (expand-file-name "pro-packages.el" pro-emacs-base-system-modules-dir))
    (load (expand-file-name "pro-packages.el" pro-emacs-base-system-modules-dir) nil t))
  ;; Now load site-init which will load configured modules
  (load (expand-file-name "site-init.el" base-dir) nil t)
  (pro-emacs-base-start))

(provide 'pro-init)
